<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;

final class SimulationManager
{
    public const RATES = [10, 25, 50, 100];

    public const DURATIONS = [10, 30];

    public const PATTERNS = ['views', 'balanced', 'orders'];

    public const DAILY_EVENT_LIMIT = 20000;

    private const ACTIVE_KEY = 'demo-simulation:active';

    private const LOCK_KEY = 'demo-simulation:mutex';

    private const STATE_TTL_SECONDS = 180;

    private const COOLDOWN_MS = 60000;

    /**
     * @return array<string, mixed>
     */
    public function start(string $owner, string $pattern, int $rate, int $duration): array
    {
        if (
            !in_array($pattern, self::PATTERNS, true)
            || !in_array($rate, self::RATES, true)
            || !in_array($duration, self::DURATIONS, true)
        ) {
            abort(422, 'Unsupported simulation configuration.');
        }

        $endpoint = config('services.ingestion.url');

        if (!is_string($endpoint) || $endpoint === '') {
            abort(503, 'The event ingestion endpoint is not configured.');
        }

        return $this->synchronised(function () use ($owner, $pattern, $rate, $duration) {
            $now = $this->nowMs();
            $existing = Cache::get(self::ACTIVE_KEY);

            if (is_array($existing)) {
                if ($existing['status'] === 'running' && $now < $existing['ends_at_ms']) {
                    abort(409, 'A simulation is already running.');
                }

                $lastEnd = $existing['stopped_at_ms'] ?? $existing['ends_at_ms'];

                if ($now < $lastEnd + self::COOLDOWN_MS) {
                    abort(429, 'Please wait before starting another simulation.');
                }
            }

            $total = $rate * $duration;

            if ($this->dailyUsed() + $total > self::DAILY_EVENT_LIMIT) {
                abort(429, 'The daily simulation event allowance is exhausted.');
            }

            $state = [
                'id' => (string) Str::uuid(),
                'owner' => hash('sha256', $owner),
                'pattern' => $pattern,
                'rate' => $rate,
                'duration' => $duration,
                'status' => 'running',
                'started_at_ms' => $now,
                'ends_at_ms' => $now + ($duration * 1000),
                'last_refill_ms' => $now,
                'tokens' => (float) TrafficSimulator::MAX_BATCH_SIZE,
                'attempted' => 0,
                'accepted' => 0,
                'rejected' => 0,
                'throttled' => 0,
                'failed' => 0,
            ];

            $this->save($state);

            return $this->snapshot($state, $owner);
        });
    }

    /**
     *
     * @return array<string, mixed>
     */
    public function reserve(string $id, string $owner, int $count): array
    {
        if ($count < 1 || $count > TrafficSimulator::MAX_BATCH_SIZE) {
            abort(422, 'Batch size must be between 1 and 10.');
        }

        return $this->synchronised(function () use ($id, $owner, $count) {
            $state = $this->ownedState($id, $owner);
            $now = $this->nowMs();

            if ($state['status'] !== 'running' || $now >= $state['ends_at_ms']) {
                abort(409, 'This simulation has ended.');
            }

            if ($state['attempted'] + $count > $state['rate'] * $state['duration']) {
                abort(429, 'Simulation event limit reached.');
            }

            $elapsedMs = max(0, $now - $state['last_refill_ms']);

            $tokens = min(
                (float) TrafficSimulator::MAX_BATCH_SIZE,
                $state['tokens'] + ($elapsedMs * $state['rate'] / 1000),
            );

            if ($count > $tokens + 0.000001) {
                abort(429, 'Simulation rate limit reached.');
            }

            $dailyUsed = $this->dailyUsed();

            if ($dailyUsed + $count > self::DAILY_EVENT_LIMIT) {
                abort(429, 'The daily simulation event allowance is exhausted.');
            }

            $state['tokens'] = $tokens - $count;
            $state['last_refill_ms'] = $now;
            $state['attempted'] += $count;

            Cache::put($this->dailyKey(), $dailyUsed + $count, now()->utc()->endOfDay());
            $this->save($state);

            return ['pattern' => $state['pattern'], 'count' => $count];
        });
    }

    /**
     * @param array{attempted: int, accepted: int, rejected: int, throttled: int, failed: int} $result
     */
    public function recordResult(string $id, array $result): void
    {
        $this->synchronised(function () use ($id, $result) {
            $state = Cache::get(self::ACTIVE_KEY);

            if (!is_array($state) || $state['id'] !== $id) {
                return;
            }

            foreach (['accepted', 'rejected', 'throttled', 'failed'] as $field) {
                $state[$field] += $result[$field];
            }

            $this->save($state);
        });
    }

    /**
     * @return array<string, mixed>
     */
    public function stop(string $id, string $owner): array
    {
        return $this->synchronised(function () use ($id, $owner) {
            $state = $this->ownedState($id, $owner);

            if ($state['status'] === 'running') {
                $state['status'] = 'stopped';
                $state['stopped_at_ms'] = $this->nowMs();
                $this->save($state);
            }

            return $this->snapshot($state, $owner);
        });
    }

    /**
     * @return array<string, mixed>
     */
    public function status(string $owner): array
    {
        $state = Cache::get(self::ACTIVE_KEY);

        if (!is_array($state)) {
            return [
                'status' => 'idle',
                'daily_remaining' => max(0, self::DAILY_EVENT_LIMIT - $this->dailyUsed()),
            ];
        }

        return $this->snapshot($state, $owner);
    }

    /**
     * @return list<string>
     */
    public function eventTypes(string $pattern, int $count): array
    {
        [$views, $carts] = match ($pattern) {
            'views' => [90, 8],
            'balanced' => [50, 30],
            'orders' => [20, 20],
            default => throw new \InvalidArgumentException('Unsupported traffic pattern.'),
        };

        $types = [];

        for ($i = 0; $i < $count; $i++) {
            $roll = random_int(1, 100);

            $types[] = match (true) {
                $roll <= $views => 'product_viewed',
                $roll <= $views + $carts => 'cart_item_added',
                default => 'order_completed',
            };
        }

        return $types;
    }

    /**
     * @return array<string, mixed>
     */
    private function ownedState(string $id, string $owner): array
    {
        $state = Cache::get(self::ACTIVE_KEY);

        if (!is_array($state) || $state['id'] !== $id) {
            abort(404, 'Simulation not found.');
        }

        if (!hash_equals($state['owner'], hash('sha256', $owner))) {
            abort(403, 'You cannot control another visitor\'s simulation.');
        }

        return $state;
    }

    /**
     * @param array<string, mixed> $state
     * @return array<string, mixed>
     */
    private function snapshot(array $state, string $owner): array
    {
        $canControl = hash_equals($state['owner'], hash('sha256', $owner));
        $status = $state['status'];

        if ($status === 'running' && $this->nowMs() >= $state['ends_at_ms']) {
            $status = 'completed';
        }

        return [
            'id' => $canControl ? $state['id'] : null,
            'status' => $status,
            'can_control' => $canControl,
            'pattern' => $state['pattern'],
            'rate' => $state['rate'],
            'duration' => $state['duration'],
            'remaining_seconds' => $status === 'running'
                ? (int) ceil(max(0, $state['ends_at_ms'] - $this->nowMs()) / 1000)
                : 0,
            'attempted' => $state['attempted'],
            'accepted' => $state['accepted'],
            'rejected' => $state['rejected'],
            'throttled' => $state['throttled'],
            'failed' => $state['failed'],
            'daily_remaining' => max(0, self::DAILY_EVENT_LIMIT - $this->dailyUsed()),
        ];
    }

    /** @param array<string, mixed> $state */
    private function save(array $state): void
    {
        Cache::put(self::ACTIVE_KEY, $state, now()->addSeconds(self::STATE_TTL_SECONDS));
    }

    private function dailyKey(): string
    {
        return 'demo-simulation:daily:' . now()->utc()->toDateString();
    }

    private function dailyUsed(): int
    {
        return (int) Cache::get($this->dailyKey(), 0);
    }

    private function nowMs(): int
    {
        return now()->getTimestampMs();
    }

    private function synchronised(callable $callback): mixed
    {
        $lock = Cache::lock(self::LOCK_KEY, 5);

        if (!$lock->get()) {
            abort(429, 'Simulation is busy. Please retry.');
        }

        try {
            return $callback();
        } finally {
            $lock->release();
        }
    }
}
