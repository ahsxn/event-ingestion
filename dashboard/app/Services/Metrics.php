<?php

declare(strict_types=1);

namespace App\Services;

use Aws\DynamoDb\DynamoDbClient;
use Aws\DynamoDb\Marshaler;

final class Metrics
{
    public function __construct(
        private readonly DynamoDbClient $dynamo,
        private readonly Marshaler $marshaler
    ) {
    }

    public function dashboard(): array
    {
        $metrics = $this->globalMetrics();

        return [
            'metrics' => [
                ...$metrics,

                'average_order_value' =>
                    $metrics['orders'] > 0
                    ? $metrics['revenue'] / $metrics['orders']
                    : 0,

                'cart_view_ratio' =>
                    $metrics['product_views'] > 0
                    ? $metrics['cart_adds'] / $metrics['product_views']
                    : 0,
            ],

            'products' => $this->productMetrics(),
        ];
    }

    private function globalMetrics(): array
    {
        $names = [
            'product_views',
            'cart_adds',
            'orders',
            'revenue',
        ];

        $values = array_fill_keys($names, 0);

        $result = $this->dynamo->batchGetItem([
            'RequestItems' => [
                config('services.aws.metrics_table') => [
                    'Keys' => array_map(
                        fn(string $metric) => [
                            'metric' => ['S' => $metric],
                            'dimension' => ['S' => 'all'],
                        ],
                        $names,
                    ),
                ],
            ],
        ]);

        foreach (
            $result['Responses'][config('services.aws.metrics_table')] ?? []
            as $item
        ) {
            $item = $this->marshaler->unmarshalItem($item);

            $values[$item['metric']] = (int) $item['value'];
        }

        return $values;
    }


    private function productMetrics(): array
    {
        $views = $this->productMetric('product_views');
        $cartAdds = $this->productMetric('cart_adds');

        $productIds = array_unique([
            ...array_keys($views),
            ...array_keys($cartAdds),
        ]);

        $products = array_map(
            function (string $productId) use ($views, $cartAdds) {
                $productViews = $views[$productId] ?? 0;
                $productCartAdds = $cartAdds[$productId] ?? 0;

                return [
                    'product' => $productId,
                    'views' => $productViews,
                    'cart_adds' => $productCartAdds,

                    'cart_view_ratio' => $productViews > 0
                        ? $productCartAdds / $productViews
                        : 0,
                ];
            },
            $productIds,
        );

        usort(
            $products,
            fn(array $a, array $b) =>
                $b['views'] <=> $a['views'],
        );

        return \array_slice($products, 0, 10);
    }

    private function productMetric(string $metric): array
    {
        $result = $this->dynamo->query([
            'TableName' => config('services.aws.metrics_table'),

            'KeyConditionExpression' =>
                'metric = :metric AND begins_with(dimension, :prefix)',

            'ExpressionAttributeValues' => [
                ':metric' => ['S' => $metric],
                ':prefix' => ['S' => 'product:'],
            ],
        ]);

        $values = [];

        foreach ($result['Items'] ?? [] as $item) {
            $item = $this->marshaler->unmarshalItem($item);

            $product = str_replace('product:', '', $item['dimension']);

            $values[$product] = (int) $item['value'];
        }

        return $values;
    }
}