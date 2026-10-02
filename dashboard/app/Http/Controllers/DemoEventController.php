<?php

namespace App\Http\Controllers;

use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class DemoEventController extends Controller
{
    public function __invoke(
        string $type,
    ): RedirectResponse {
        $productId = collect([
            'prod_123',
            'prod_456',
            'prod_789',
        ])->random();

        $data = match ($type) {
            'product_viewed' => [
                'product_id' => $productId,
            ],

            'cart_item_added' => [
                'product_id' => $productId,
                'quantity' => random_int(1, 3),
            ],

            'order_completed' => [
                'order_id' => (string) Str::uuid(),
                'total_pence' => random_int(2500, 15000),
            ],

            default => abort(404),
        };

        $response = Http::post(
            config('services.ingestion.url'),
            [
                'id' => (string) Str::uuid(),
                'type' => $type,
                'timestamp' => now()->utc()->toIso8601String(),
                'data' => $data,
            ],
        );

        $response->throw();

        return back();
    }
}
