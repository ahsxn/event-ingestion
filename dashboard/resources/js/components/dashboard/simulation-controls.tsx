import { Activity, Play, Square } from 'lucide-react';
import { useState } from 'react';

import {
    type SimulationDuration,
    type TrafficPattern,
    type TrafficRate,
    type useSimulation,
} from '@/hooks/use-simulation';

const patterns: {
    value: TrafficPattern;
    label: string;
    description: string;
}[] = [
    {
        value: 'views',
        label: 'Product views',
        description: '90% views · 8% carts · 2% orders',
    },
    {
        value: 'balanced',
        label: 'Balanced',
        description: '50% views · 30% carts · 20% orders',
    },
    {
        value: 'orders',
        label: 'Order-heavy',
        description: '20% views · 20% carts · 60% orders',
    },
];

const rates: TrafficRate[] = [10, 25, 50, 100];
const durations: SimulationDuration[] = [10, 30];

type Props = {
    controller: ReturnType<typeof useSimulation>;
};

export function SimulationControls({ controller }: Props) {
    const [pattern, setPattern] = useState<TrafficPattern>('views');
    const [rate, setRate] = useState<TrafficRate>(100);
    const [duration, setDuration] = useState<SimulationDuration>(30);

    const { simulation, loading, busy, error, start, stop, clearError } =
        controller;

    const running = simulation?.status === 'running';
    const canControl = simulation?.can_control ?? false;
    const cooldown = simulation?.cooldown_seconds ?? 0;
    const dailyRemaining = simulation?.daily_remaining ?? 0;
    const expectedEvents = rate * duration;
    const canStart =
        !loading &&
        !busy &&
        !running &&
        cooldown === 0 &&
        dailyRemaining >= expectedEvents;

    const attempted = simulation?.attempted ?? 0;
    const runLimit =
        (simulation?.rate ?? rate) * (simulation?.duration ?? duration);
    const progress = Math.min(
        100,
        runLimit > 0 ? (attempted / runLimit) * 100 : 0,
    );

    const statusLabel = running
        ? 'Running'
        : simulation?.status === 'completed'
          ? 'Completed'
          : simulation?.status === 'stopped'
            ? 'Stopped'
            : 'Ready';

    return (
        <section className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
            <div className="flex flex-wrap items-start justify-between gap-3 border-b border-gray-100 px-6 py-5">
                <div>
                    <div className="flex items-center gap-2">
                        <Activity
                            className="size-5 text-emerald-600"
                            aria-hidden="true"
                        />
                        <h2 className="font-semibold text-gray-900">
                            Traffic simulator
                        </h2>
                    </div>
                    <p className="mt-1 max-w-2xl text-sm text-gray-500">
                        Generate real e-commerce events through API Gateway,
                        Lambda and Kinesis. Watch the analytics below update as
                        the worker processes them.
                    </p>
                </div>

                <span
                    aria-live="polite"
                    className={`rounded-full px-3 py-1 text-xs font-semibold ${
                        running
                            ? 'bg-emerald-100 text-emerald-800'
                            : 'bg-gray-100 text-gray-600'
                    }`}
                >
                    <span
                        className={`mr-1.5 inline-block size-1.5 rounded-full ${
                            running ? 'bg-emerald-500' : 'bg-gray-400'
                        }`}
                    />
                    {statusLabel}
                </span>
            </div>

            <div className="space-y-5 p-6">
                <div className="grid gap-4 md:grid-cols-3">
                    <div className="md:col-span-1">
                        <label
                            htmlFor="simulation-pattern"
                            className="mb-2 block text-sm font-medium text-gray-700"
                        >
                            Traffic pattern
                        </label>
                        <select
                            id="simulation-pattern"
                            value={pattern}
                            onChange={(event) =>
                                setPattern(event.target.value as TrafficPattern)
                            }
                            disabled={running || busy}
                            className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2.5 text-sm text-gray-900 disabled:opacity-60"
                        >
                            {patterns.map((option) => (
                                <option key={option.value} value={option.value}>
                                    {option.label}
                                </option>
                            ))}
                        </select>
                        <p className="mt-2 text-xs text-gray-500">
                            {
                                patterns.find(
                                    (option) => option.value === pattern,
                                )?.description
                            }
                        </p>
                    </div>

                    <div>
                        <label
                            htmlFor="simulation-rate"
                            className="mb-2 block text-sm font-medium text-gray-700"
                        >
                            Events per second
                        </label>
                        <select
                            id="simulation-rate"
                            value={rate}
                            onChange={(event) =>
                                setRate(
                                    Number(event.target.value) as TrafficRate,
                                )
                            }
                            disabled={running || busy}
                            className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2.5 text-sm text-gray-900 disabled:opacity-60"
                        >
                            {rates.map((value) => (
                                <option key={value} value={value}>
                                    {value} events/sec
                                </option>
                            ))}
                        </select>
                    </div>

                    <div>
                        <label
                            htmlFor="simulation-duration"
                            className="mb-2 block text-sm font-medium text-gray-700"
                        >
                            Duration
                        </label>
                        <select
                            id="simulation-duration"
                            value={duration}
                            onChange={(event) =>
                                setDuration(
                                    Number(
                                        event.target.value,
                                    ) as SimulationDuration,
                                )
                            }
                            disabled={running || busy}
                            className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2.5 text-sm text-gray-900 disabled:opacity-60"
                        >
                            {durations.map((value) => (
                                <option key={value} value={value}>
                                    {value} seconds
                                </option>
                            ))}
                        </select>
                    </div>
                </div>

                <div className="flex flex-wrap items-center justify-between gap-4 rounded-lg bg-gray-50 p-4">
                    <div>
                        <div className="text-xs font-medium tracking-wide text-gray-500 uppercase">
                            Planned maximum
                        </div>
                        <div className="mt-1 text-xl font-semibold text-gray-900 tabular-nums">
                            {expectedEvents.toLocaleString()}{' '}
                            <span className="text-sm font-normal text-gray-500">
                                events
                            </span>
                        </div>
                    </div>

                    {running && canControl ? (
                        <button
                            type="button"
                            onClick={() => void stop()}
                            disabled={busy}
                            className="inline-flex items-center gap-2 rounded-lg border border-red-200 bg-white px-5 py-2.5 text-sm font-semibold text-red-700 hover:bg-red-50 disabled:opacity-50"
                        >
                            <Square className="size-4" aria-hidden="true" />
                            {busy ? 'Stopping…' : 'Stop simulation'}
                        </button>
                    ) : (
                        <button
                            type="button"
                            onClick={() => {
                                clearError();
                                void start(pattern, rate, duration);
                            }}
                            disabled={!canStart}
                            className="inline-flex items-center gap-2 rounded-lg bg-gray-900 px-5 py-2.5 text-sm font-semibold text-white hover:bg-gray-800 disabled:cursor-not-allowed disabled:opacity-50"
                        >
                            <Play className="size-4" aria-hidden="true" />
                            {busy ? 'Starting…' : 'Start simulation'}
                        </button>
                    )}
                </div>

                {running && !canControl && (
                    <p className="rounded-lg bg-blue-50 px-4 py-3 text-sm text-blue-800">
                        Another visitor is running a simulation. You can watch
                        the metrics update below.
                    </p>
                )}

                {!running && cooldown > 0 && (
                    <p className="text-sm text-amber-700">
                        Cooldown in progress. Another simulation can start in
                        approximately {cooldown} seconds.
                    </p>
                )}

                {!loading && dailyRemaining < expectedEvents && !running && (
                    <p className="text-sm text-amber-700">
                        This run would exceed today&apos;s remaining event
                        allowance. Choose a lower rate or shorter duration.
                    </p>
                )}

                {error && (
                    <p
                        role="alert"
                        className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
                    >
                        {error}
                    </p>
                )}

                {simulation && simulation.status !== 'idle' && (
                    <div className="space-y-3 border-t border-gray-100 pt-5">
                        <div className="flex flex-wrap items-center justify-between gap-2">
                            <h3 className="text-sm font-semibold text-gray-900">
                                Simulation progress
                            </h3>
                            <span className="text-xs text-gray-500 tabular-nums">
                                {running
                                    ? `${simulation.remaining_seconds ?? 0}s remaining`
                                    : statusLabel}
                            </span>
                        </div>

                        <div
                            role="progressbar"
                            aria-label="Event submission progress"
                            aria-valuenow={Math.round(progress)}
                            aria-valuemin={0}
                            aria-valuemax={100}
                            className="h-2 overflow-hidden rounded-full bg-gray-100"
                        >
                            <div
                                className="h-full rounded-full bg-emerald-500 transition-all"
                                style={{ width: `${progress}%` }}
                            />
                        </div>

                        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                            {[
                                { label: 'Attempted', value: attempted },
                                {
                                    label: 'Accepted',
                                    value: simulation.accepted ?? 0,
                                },
                                {
                                    label: 'Throttled',
                                    value: simulation.throttled ?? 0,
                                },
                                {
                                    label: 'Failed',
                                    value:
                                        (simulation.failed ?? 0) +
                                        (simulation.rejected ?? 0),
                                },
                            ].map((item) => (
                                <div
                                    key={item.label}
                                    className="rounded-lg border border-gray-100 p-3"
                                >
                                    <div className="text-xs text-gray-500">
                                        {item.label}
                                    </div>
                                    <div className="mt-1 text-lg font-semibold text-gray-900 tabular-nums">
                                        {item.value.toLocaleString()}
                                    </div>
                                </div>
                            ))}
                        </div>

                        <p className="text-xs text-gray-500">
                            Accepted means the ingestion API returned HTTP 202.
                            Events are processed asynchronously by the ECS
                            worker.
                        </p>
                    </div>
                )}

                <p className="text-xs text-gray-400">
                    Shared demo · One active simulation · 30-second maximum ·
                    100 events/sec maximum ·
                    {` ${dailyRemaining.toLocaleString()} `}daily attempts
                    remaining
                </p>
            </div>
        </section>
    );
}
