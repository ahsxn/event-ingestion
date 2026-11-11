import { useCallback, useEffect, useRef, useState } from 'react';

export type TrafficPattern = 'views' | 'balanced' | 'orders';
export type TrafficRate = 10 | 25 | 50 | 100;
export type SimulationDuration = 10 | 30;

export type SimulationSnapshot = {
    id?: string | null;
    status: 'idle' | 'running' | 'stopped' | 'completed';
    can_control?: boolean;
    pattern?: TrafficPattern;
    rate?: TrafficRate;
    duration?: SimulationDuration;
    remaining_seconds?: number;
    cooldown_seconds?: number;
    attempted?: number;
    accepted?: number;
    rejected?: number;
    throttled?: number;
    failed?: number;
    daily_remaining: number;
};

type BatchResult = {
    attempted: number;
    accepted: number;
    rejected: number;
    throttled: number;
    failed: number;
};

type PulseResponse = {
    batch: BatchResult;
    simulation: SimulationSnapshot;
};

class SimulationRequestError extends Error {
    constructor(
        readonly status: number,
        message: string,
    ) {
        super(message);
    }
}

async function request<T>(
    url: string,
    method: 'GET' | 'POST',
    body?: object,
): Promise<T> {
    const csrfToken = document.querySelector<HTMLMetaElement>(
        'meta[name="csrf-token"]',
    )?.content;

    const response = await fetch(url, {
        method,
        credentials: 'same-origin',
        headers: {
            Accept: 'application/json',
            'Content-Type': 'application/json',
            ...(csrfToken ? { 'X-CSRF-TOKEN': csrfToken } : {}),
        },
        ...(body ? { body: JSON.stringify(body) } : {}),
    });

    const payload: unknown = await response.json().catch(() => ({}));

    if (!response.ok) {
        const error = payload as { message?: string; error?: string };

        throw new SimulationRequestError(
            response.status,
            error.message ??
                error.error ??
                `Request failed (${response.status}).`,
        );
    }

    return payload as T;
}

function mergeSnapshot(
    previous: SimulationSnapshot | null,
    incoming: SimulationSnapshot,
): SimulationSnapshot {
    if (!previous || !previous.id || previous.id !== incoming.id) {
        return incoming;
    }

    const terminal =
        previous.status === 'stopped' || previous.status === 'completed';

    return {
        ...incoming,
        status:
            terminal && incoming.status === 'running'
                ? previous.status
                : incoming.status,
        attempted: Math.max(previous.attempted ?? 0, incoming.attempted ?? 0),
        accepted: Math.max(previous.accepted ?? 0, incoming.accepted ?? 0),
        rejected: Math.max(previous.rejected ?? 0, incoming.rejected ?? 0),
        throttled: Math.max(previous.throttled ?? 0, incoming.throttled ?? 0),
        failed: Math.max(previous.failed ?? 0, incoming.failed ?? 0),
    };
}

function errorMessage(error: unknown): string {
    return error instanceof Error
        ? error.message
        : 'Something went wrong with the simulation.';
}

export function useSimulation() {
    const [simulation, setSimulation] = useState<SimulationSnapshot | null>(
        null,
    );
    const [loading, setLoading] = useState(true);
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const paused = useRef(false);
    const pulseInFlight = useRef(false);
    const actionVersion = useRef(0);

    const updateSnapshot = useCallback((incoming: SimulationSnapshot) => {
        setSimulation((previous) => mergeSnapshot(previous, incoming));
    }, []);

    const refreshStatus = useCallback(async () => {
        const version = actionVersion.current;

        try {
            const status = await request<SimulationSnapshot>(
                '/simulations/status',
                'GET',
            );

            if (version === actionVersion.current) {
                updateSnapshot(status);
            }
        } catch (cause) {
            setError(errorMessage(cause));
        } finally {
            setLoading(false);
        }
    }, [updateSnapshot]);

    useEffect(() => {
        void refreshStatus();

        const interval = window.setInterval(() => {
            void refreshStatus();
        }, 1500);

        return () => window.clearInterval(interval);
    }, [refreshStatus]);

    const runningId =
        simulation?.status === 'running' && simulation.can_control
            ? simulation.id
            : null;
    const runningRate = simulation?.rate;

    useEffect(() => {
        if (!runningId || !runningRate) {
            return;
        }

        let disposed = false;
        let fractionalEvents = 0;

        const interval = window.setInterval(() => {
            if (
                disposed ||
                paused.current ||
                pulseInFlight.current ||
                document.hidden
            ) {
                return;
            }

            fractionalEvents += runningRate / 10;
            const count = Math.min(10, Math.floor(fractionalEvents));
            fractionalEvents -= count;

            if (count < 1) {
                return;
            }

            pulseInFlight.current = true;

            void request<PulseResponse>(
                `/simulations/${runningId}/pulse`,
                'POST',
                { count },
            )
                .then((result) => {
                    if (!disposed) {
                        updateSnapshot(result.simulation);
                    }
                })
                .catch((cause: unknown) => {
                    if (disposed) {
                        return;
                    }

                    // A pulse may arrive slightly ahead of the server token bucket.
                    // Skip that pulse; never queue requests to catch up later.
                    if (
                        cause instanceof SimulationRequestError &&
                        cause.status === 429 &&
                        cause.message.includes('rate limit')
                    ) {
                        return;
                    }

                    paused.current = true;
                    setError(errorMessage(cause));
                    void refreshStatus();
                })
                .finally(() => {
                    pulseInFlight.current = false;
                });
        }, 100);

        return () => {
            disposed = true;
            window.clearInterval(interval);
        };
    }, [runningId, runningRate, refreshStatus, updateSnapshot]);

    const start = async (
        pattern: TrafficPattern,
        rate: TrafficRate,
        duration: SimulationDuration,
    ) => {
        setBusy(true);
        setError(null);
        actionVersion.current++;

        try {
            const status = await request<SimulationSnapshot>(
                '/simulations',
                'POST',
                {
                    pattern,
                    rate,
                    duration,
                },
            );

            paused.current = false;
            updateSnapshot(status);
        } catch (cause) {
            setError(errorMessage(cause));
            await refreshStatus();
        } finally {
            setBusy(false);
        }
    };

    const stop = async () => {
        if (!runningId) {
            return;
        }

        paused.current = true;
        setBusy(true);
        setError(null);
        actionVersion.current++;

        try {
            const status = await request<SimulationSnapshot>(
                `/simulations/${runningId}/stop`,
                'POST',
            );

            updateSnapshot(status);
        } catch (cause) {
            setError(errorMessage(cause));
            await refreshStatus();
        } finally {
            setBusy(false);
        }
    };

    return {
        simulation,
        loading,
        busy,
        error,
        start,
        stop,
        clearError: () => setError(null),
    };
}
