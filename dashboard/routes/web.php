<?php

use App\Http\Controllers\DashboardController;
use App\Http\Controllers\DemoEventController;
use Illuminate\Support\Facades\Route;

Route::get('/', DashboardController::class)
    ->name('dashboard');

Route::post(
    '/demo-events/{type}',
    DemoEventController::class,
)->name('demo-events.store');

require __DIR__ . '/settings.php';
