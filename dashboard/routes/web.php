<?php

use App\Http\Controllers\DashboardController;
use App\Http\Controllers\DemoEventController;
use App\Http\Controllers\SimulationController;
use Illuminate\Support\Facades\Route;

Route::get('/', DashboardController::class)
    ->name('dashboard');

Route::post(
    '/demo-events/{type}',
    DemoEventController::class,
)->name('demo-events.store');

Route::post('/simulations', [SimulationController::class, 'start'])
    ->middleware('throttle:6,1,simulation-start')
    ->name('simulations.start');

Route::post('/simulations/{id}/pulse', [SimulationController::class, 'pulse'])
    ->middleware('throttle:650,1,simulation-pulse')
    ->name('simulations.pulse');

Route::post('/simulations/{id}/stop', [SimulationController::class, 'stop'])
    ->middleware('throttle:30,1,simulation-stop')
    ->name('simulations.stop');

Route::get('/simulations/status', [SimulationController::class, 'status'])
    ->middleware('throttle:120,1,simulation-status')
    ->name('simulations.status');


require __DIR__ . '/settings.php';
