<?php

namespace App\Http\Controllers;

use App\Services\EventFactory;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Http;
use InvalidArgumentException;

class DemoEventController extends Controller
{
    public function __invoke(
        EventFactory $factory,
        string $type,
    ): RedirectResponse {
        try {
            $event = $factory->create($type);
        } catch (InvalidArgumentException) {
            abort(404);
        }

        $response = Http::post(
            config('services.ingestion.url'),
            $event,
        );

        $response->throw();

        return back();
    }
}
