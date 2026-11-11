import { Activity } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';

import type { SimulationSnapshot } from '@/hooks/use-simulation';
import type { Metrics } from '@/types/dashboard';

const SAMPLE_INTERVAL_MS = 1500;
const MAX_SAMPLES = 40;
const PLOT = { left: 48, right: 776, top: 16, bottom: 206 };

type Sample = {
    time: string;
    accepted: number;
    processed: number;
};

type Baseline = {
    sampledAt: number;
    accepted: number;
    processed: number;
};

type Props = {
    metrics: Metrics;
    simulation: SimulationSnapshot | null;
};

function processedTotal(metrics: Metrics): number {
    return metrics.product_views + metrics.cart_adds + metrics.orders;
}

function pointsFor(
    samples: Sample[],
    field: 'accepted' | 'processed',
    max: number,
): string {
    const width = PLOT.right - PLOT.left;
    const height = PLOT.bottom - PLOT.top;

    return samples
        .map((sample, index) => {
            const x =
                PLOT.left + (index / Math.max(1, samples.length - 1)) * width;
            const y = PLOT.bottom - (sample[field] / max) * height;

            return `${x.toFixed(1)},${y.toFixed(1)}`;
        })
        .join(' ');
}

export function ThroughputChart({ metrics, simulation }: Props) {
    const [samples, setSamples] = useState<Sample[]>([]);
    const latestRef = useRef({ metrics, simulation });
    const baselineRef = useRef<Baseline | null>(null);
    const previousRunRef = useRef<string | null>(null);

    useEffect(() => {
        latestRef.current = { metrics, simulation };
    }, [metrics, simulation]);

    // The server hides a run's ID from other visitors. The running/idle
    // transition still lets them follow a shared run without controlling it.
    const runKey =
        simulation?.status === 'running'
            ? (simulation.id ?? 'shared-run')
            : null;

    useEffect(() => {
        if (!runKey) {
            previousRunRef.current = null;
            return;
        }

        if (runKey === previousRunRef.current) {
            return;
        }

        previousRunRef.current = runKey;
        baselineRef.current = {
            sampledAt: Date.now(),
            accepted: latestRef.current.simulation?.accepted ?? 0,
            processed: processedTotal(latestRef.current.metrics),
        };
        setSamples([]);
    }, [runKey]);

    useEffect(() => {
        const interval = window.setInterval(() => {
            if (!baselineRef.current) {
                return;
            }

            const { metrics: currentMetrics, simulation: currentSimulation } =
                latestRef.current;
            const sampledAt = Date.now();
            const currentAccepted = currentSimulation?.accepted ?? 0;
            const currentProcessed = processedTotal(currentMetrics);
            const baseline = baselineRef.current;
            const seconds = Math.max(
                0.1,
                (sampledAt - baseline.sampledAt) / 1000,
            );

            const accepted =
                Math.max(0, currentAccepted - baseline.accepted) / seconds;
            const processed =
                Math.max(0, currentProcessed - baseline.processed) / seconds;

            baselineRef.current = {
                sampledAt,
                accepted: currentAccepted,
                processed: currentProcessed,
            };

            setSamples((previous) =>
                [
                    ...previous,
                    {
                        time: new Date(sampledAt).toLocaleTimeString(),
                        accepted,
                        processed,
                    },
                ].slice(-MAX_SAMPLES),
            );
        }, SAMPLE_INTERVAL_MS);

        return () => window.clearInterval(interval);
    }, []);

    const latest = samples.at(-1);
    const peak = Math.max(
        10,
        ...samples.flatMap((sample) => [sample.accepted, sample.processed]),
    );
    const yMax = Math.ceil(peak / 10) * 10;
    const canPlot = samples.length >= 2;

    return (
        <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
            <div className="flex flex-wrap items-start justify-between gap-4">
                <div>
                    <div className="flex items-center gap-2">
                        <Activity
                            className="size-5 text-blue-600"
                            aria-hidden="true"
                        />
                        <h2 className="font-semibold text-gray-900">
                            Live event throughput
                        </h2>
                    </div>
                    <p className="mt-1 text-sm text-gray-500">
                        A rolling 60-second view of API acceptance and observed
                        worker output.
                    </p>
                </div>
                <div className="flex flex-wrap gap-5 text-sm">
                    <div>
                        <div className="flex items-center gap-2 text-gray-500">
                            <span className="size-2.5 rounded-full bg-emerald-600" />
                            API accepted
                        </div>
                        <div className="mt-1 font-semibold text-gray-900 tabular-nums">
                            {latest?.accepted.toFixed(1) ?? '—'}{' '}
                            <span className="text-xs font-normal text-gray-500">
                                events/s
                            </span>
                        </div>
                    </div>
                    <div>
                        <div className="flex items-center gap-2 text-gray-500">
                            <span className="size-2.5 rounded-full bg-blue-600" />
                            Observed processed
                        </div>
                        <div className="mt-1 font-semibold text-gray-900 tabular-nums">
                            {latest?.processed.toFixed(1) ?? '—'}{' '}
                            <span className="text-xs font-normal text-gray-500">
                                events/s
                            </span>
                        </div>
                    </div>
                </div>
            </div>

            <div className="relative mt-6">
                <svg
                    viewBox="0 0 800 230"
                    className="w-full"
                    role="img"
                    aria-label="Time series comparing ingestion API accepted events per second with estimated processed events per second"
                >
                    {[0, 0.5, 1].map((portion) => {
                        const y =
                            PLOT.bottom - portion * (PLOT.bottom - PLOT.top);

                        return (
                            <g key={portion}>
                                <line
                                    x1={PLOT.left}
                                    x2={PLOT.right}
                                    y1={y}
                                    y2={y}
                                    stroke="#e5e7eb"
                                    strokeDasharray={
                                        portion === 0 ? undefined : '4 5'
                                    }
                                />
                                <text
                                    x={PLOT.left - 12}
                                    y={y + 4}
                                    textAnchor="end"
                                    fill="#6b7280"
                                    fontSize="12"
                                >
                                    {Math.round(yMax * portion)}
                                </text>
                            </g>
                        );
                    })}

                    {canPlot && (
                        <>
                            <polyline
                                points={pointsFor(samples, 'accepted', yMax)}
                                fill="none"
                                stroke="#059669"
                                strokeWidth="3"
                                strokeLinejoin="round"
                                strokeLinecap="round"
                                vectorEffect="non-scaling-stroke"
                            />
                            <polyline
                                points={pointsFor(samples, 'processed', yMax)}
                                fill="none"
                                stroke="#2563eb"
                                strokeWidth="3"
                                strokeLinejoin="round"
                                strokeLinecap="round"
                                vectorEffect="non-scaling-stroke"
                            />
                        </>
                    )}
                </svg>

                {!canPlot && (
                    <p className="absolute inset-0 flex items-center justify-center text-sm text-gray-500">
                        {baselineRef.current
                            ? 'Collecting throughput samples…'
                            : 'Start a simulation to see live throughput.'}
                    </p>
                )}
                {canPlot && (
                    <div className="flex justify-between pr-6 pl-12 text-xs text-gray-400">
                        <span>{samples[0].time}</span>
                        <span>{samples[samples.length - 1].time}</span>
                    </div>
                )}
            </div>

            <p className="mt-4 text-xs leading-relaxed text-gray-500">
                Accepted = HTTP 202 responses for this simulation. Processed ≈
                changes in the system-wide DynamoDB event counters (views + cart
                adds + orders). Processing can lag ingestion and may include
                other visitors&apos; traffic, so the lines are not an exact
                per-run comparison.
            </p>
        </section>
    );
}
