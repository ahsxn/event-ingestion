<?php

namespace App\Services;

use Illuminate\Http\Client\Pool;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use InvalidArgumentException;
use RuntimeException;

final class TrafficSimulator
{
    public const MAX_BATCH_SIZE = 10;

    private const MAX_CONCURRENT_REQUESTS = 5;

    private const REQUEST_TIMEOUT_SECONDS = 3;

    public function __construct(
        private readonly EventFactory $events
    ) {
    }

    /**
     * @param list<string> $types
     * @return array{attempted: int, accepted: int, rejected: int, throttled: int, failed: int}
     */
    public function sendBatch(array $types): array
    {
        if (count($types) < 1 || count($types) > self::MAX_BATCH_SIZE) {
            throw new InvalidArgumentException('A batch must contain between 1 and 10 events.');
        }

        $endpoint = config('services.ingestion.url');

        if (!is_string($endpoint) || $endpoint === '') {
            throw new RuntimeException('EVENT_INGESTION_URL is required.');
        }

        $events = [];

        foreach ($types as $type) {
            if (!is_string($type)) {
                throw new InvalidArgumentException('Event types must be strings.');
            }

            $events[] = $this->events->create($type);
        }

        $responses = Http::pool(
            fn(Pool $pool) => array_map(
                fn(array $event) => $pool
                    ->timeout(self::REQUEST_TIMEOUT_SECONDS)
                    ->post($endpoint, $event),
                $events,
            ),
            concurrency: self::MAX_CONCURRENT_REQUESTS,
        );

        $result = [
            'attempted' => count($events),
            'accepted' => 0,
            'rejected' => 0,
            'throttled' => 0,
            'failed' => 0,
        ];

        foreach ($responses as $response) {
            if (!$response instanceof Response) {
                $result['failed']++;
            } elseif ($response->status() === 202) {
                $result['accepted']++;
            } elseif ($response->status() === 429) {
                $result['throttled']++;
            } elseif ($response->clientError()) {
                $result['rejected']++;
            } else {
                $result['failed']++;
            }
        }

        return $result;
    }
}
