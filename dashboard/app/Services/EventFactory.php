<?php

namespace App\Services;

use InvalidArgumentException;
use Illuminate\Support\Str;

final class EventFactory
{
    /**
     * @return array{id: string, type: string, timestamp: string, data: array<string, int|string>}
     */
    public function create(string $type): array
    {
        $data = match ($type) {
            'product_viewed' => [
                'product_id' => $this->productId(),
            ],

            'cart_item_added' => [
                'product_id' => $this->productId(),
                'quantity' => random_int(1, 3),
            ],

            'order_completed' => [
                'order_id' => (string) Str::uuid(),
                'total_pence' => random_int(2500, 15000),
            ],

            default => throw new InvalidArgumentException("Unsupported event type: {$type}"),
        };

        return [
            'id' => (string) Str::uuid(),
            'type' => $type,
            'timestamp' => now()->utc()->toIso8601String(),
            'data' => $data,
        ];
    }

    private function productId(): string
    {
        return collect([
            'prod_123',
            'prod_456',
            'prod_789',
        ])->random();
    }
}
