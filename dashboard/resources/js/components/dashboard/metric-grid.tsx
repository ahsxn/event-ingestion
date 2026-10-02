import {
    formatCurrency,
    formatNumber,
    formatPercentage,
} from '@/lib/utils';
import type { Metrics } from '@/types/dashboard';
import { MetricCard } from './metric-card';

type Props = {
    metrics: Metrics;
};

export function MetricGrid({ metrics }: Props) {
    return (
        <section>
            <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                <MetricCard
                    label="Product Views"
                    value={formatNumber(metrics.product_views)}
                />

                <MetricCard
                    label="Cart Adds"
                    value={formatNumber(metrics.cart_adds)}
                />

                <MetricCard
                    label="Orders"
                    value={formatNumber(metrics.orders)}
                />

                <MetricCard
                    label="Revenue"
                    value={formatCurrency(metrics.revenue)}
                />
            </div>

            <div className="mt-4 grid gap-4 sm:grid-cols-2">
                <MetricCard
                    label="Average Order Value"
                    value={formatCurrency(
                        metrics.average_order_value,
                    )}
                    description="Revenue ÷ orders"
                />

                <MetricCard
                    label="Cart / View Ratio"
                    value={formatPercentage(
                        metrics.cart_view_ratio,
                    )}
                    description="Aggregate cart adds ÷ product views"
                />
            </div>
        </section>
    );
}