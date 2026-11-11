import { Head } from '@inertiajs/react';
import { MetricGrid } from '@/components/dashboard/metric-grid';
import { ProductTable } from '@/components/dashboard/product-table';
import { useDashboardPolling } from '@/hooks/use-dashboard-polling';
import type { DashboardProps } from '@/types/dashboard';
import { SimulationControls } from '@/components/dashboard/simulation-controls';
import { ThroughputChart } from '@/components/dashboard/throughput-chart';
import { useSimulation } from '@/hooks/use-simulation';

export default function Dashboard({
    metrics,
    products,
}: DashboardProps) {
    const simulationController = useSimulation();
    useDashboardPolling(simulationController.simulation?.status === 'running');

    return (
        <>
            <Head title="Commerce Stream" />

            <div className="min-h-screen bg-gray-50">
                <main className="mx-auto max-w-7xl px-6 py-10">
                    <header className="mb-8">
                        <div className="flex items-center gap-2">
                            <span className="h-2 w-2 rounded-full bg-emerald-500" />

                            <span className="text-xs font-semibold uppercase tracking-wider text-emerald-700">
                                Pipeline online
                            </span>
                        </div>

                        <h1 className="mt-3 text-3xl font-semibold tracking-tight text-gray-900">
                            Commerce Stream
                        </h1>

                        <p className="mt-2 max-w-2xl text-gray-500">
                            Event-driven e-commerce analytics powered
                            by AWS serverless and container services.
                        </p>
                    </header>

                    <div className="space-y-8">
                        {/* <Pipeline /> */}

                       <SimulationControls controller={simulationController} />

                        <ThroughputChart
                            metrics={metrics}
                            simulation={simulationController.simulation}
                        />

                        {/* <EventActions /> */}

                        <MetricGrid metrics={metrics} />

                        <ProductTable products={products} />
                    </div>
                </main>
            </div>
        </>
    );
}