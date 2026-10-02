<?php

namespace App\Providers;

use Aws\DynamoDb\DynamoDbClient;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Date;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\ServiceProvider;
use Illuminate\Validation\Rules\Password;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(DynamoDbClient::class, function () {
            $config = [
                'version' => 'latest',
                'region' => config('services.aws.region'),
            ];

            if ($endpoint = config('services.aws.endpoint')) {
                $config['endpoint'] = $endpoint;
            }

            $key = config('services.aws.key');
            $secret = config('services.aws.secret');

            if ($key && $secret) {
                $config['credentials'] = [
                    'key' => $key,
                    'secret' => $secret,
                ];
            }

            return new DynamoDbClient($config);
        });
    }

    public function boot(): void
    {
        $this->configureDefaults();
    }

    protected function configureDefaults(): void
    {
        Date::use(CarbonImmutable::class);

        DB::prohibitDestructiveCommands(
            app()->isProduction(),
        );

        Password::defaults(
            fn(): ?Password => app()->isProduction()
                ? Password::min(12)
                    ->mixedCase()
                    ->letters()
                    ->numbers()
                    ->symbols()
                    ->uncompromised()
                : null,
        );
    }
}
