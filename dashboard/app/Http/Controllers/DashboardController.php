<?php

namespace App\Http\Controllers;

use App\Services\Metrics;
use Inertia\Inertia;
use Inertia\Response;


class DashboardController extends Controller
{
    public function __invoke(
        Metrics $metrics,
    ): Response {
        return Inertia::render(
            'dashboard',
            $metrics->dashboard(),
        );
    }
}
