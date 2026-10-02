import { formatNumber, formatPercentage } from '@/lib/utils';
import type { Product } from '@/types/dashboard';

type Props = {
    products: Product[];
};

export function ProductTable({ products }: Props) {
    return (
        <section className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
            <div className="border-b border-gray-200 px-6 py-5">
                <h2 className="font-semibold text-gray-900">
                    Product metrics
                </h2>

                <p className="mt-1 text-sm text-gray-500">
                    Aggregated views and cart activity by product.
                </p>
            </div>

            <div className="overflow-x-auto">
                <table className="w-full text-left">
                    <thead className="bg-gray-50">
                        <tr className="border-b border-gray-200 text-xs uppercase tracking-wide text-gray-500">
                            <th className="px-6 py-4 font-medium">
                                Product
                            </th>

                            <th className="px-6 py-4 text-right font-medium">
                                Views
                            </th>

                            <th className="px-6 py-4 text-right font-medium">
                                Cart Adds
                            </th>

                            <th className="px-6 py-4 text-right font-medium">
                                Cart / View
                            </th>
                        </tr>
                    </thead>

                    <tbody>
                        {products.map((product) => (
                            <tr
                                key={product.product}
                                className="border-b border-gray-100 last:border-0"
                            >
                                <td className="px-6 py-4 font-mono text-sm text-gray-900">
                                    {product.product}
                                </td>

                                <td className="px-6 py-4 text-right tabular-nums text-gray-700">
                                    {formatNumber(product.views)}
                                </td>

                                <td className="px-6 py-4 text-right tabular-nums text-gray-700">
                                    {formatNumber(product.cart_adds)}
                                </td>

                                <td className="px-6 py-4 text-right tabular-nums text-gray-500">
                                    {formatPercentage(
                                        product.cart_view_ratio,
                                    )}
                                </td>
                            </tr>
                        ))}

                        {products.length === 0 && (
                            <tr>
                                <td
                                    colSpan={4}
                                    className="px-6 py-12 text-center text-sm text-gray-500"
                                >
                                    No product events have been
                                    processed yet.
                                </td>
                            </tr>
                        )}
                    </tbody>
                </table>
            </div>
        </section>
    );
}