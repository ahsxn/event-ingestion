<?php

namespace App\Http\Controllers;

use App\Services\SimulationManager;
use App\Services\TrafficSimulator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Throwable;

final class SimulationController extends Controller
{
    public function start(Request $request, SimulationManager $simulations): JsonResponse
    {
        $data = $request->validate([
            'pattern' => ['required', 'string', Rule::in(SimulationManager::PATTERNS)],
            'rate' => ['required', 'integer', Rule::in(SimulationManager::RATES)],
            'duration' => ['required', 'integer', Rule::in(SimulationManager::DURATIONS)],
        ]);

        return response()->json($simulations->start(
            $request->session()->getId(),
            $data['pattern'],
            (int) $data['rate'],
            (int) $data['duration'],
        ), 201);
    }

    public function pulse(
        Request $request,
        string $id,
        SimulationManager $simulations,
        TrafficSimulator $traffic,
    ): JsonResponse {
        $data = $request->validate([
            'count' => ['required', 'integer', 'min:1', 'max:10'],
        ]);

        $reservation = $simulations->reserve($id, $request->session()->getId(), (int) $data['count']);

        try {
            $result = $traffic->sendBatch(
                $simulations->eventTypes($reservation['pattern'], $reservation['count']),
            );
        } catch (Throwable $exception) {
            report($exception);

            $simulations->recordResult($id, [
                'attempted' => $reservation['count'],
                'accepted' => 0,
                'rejected' => 0,
                'throttled' => 0,
                'failed' => $reservation['count'],
            ]);

            return response()->json(['error' => 'Could not publish event batch.'], 502);
        }

        $simulations->recordResult($id, $result);

        return response()->json([
            'batch' => $result,
            'simulation' => $simulations->status($request->session()->getId()),
        ]);
    }

    public function stop(Request $request, string $id, SimulationManager $simulations): JsonResponse
    {
        return response()->json($simulations->stop($id, $request->session()->getId()));
    }

    public function status(Request $request, SimulationManager $simulations): JsonResponse
    {
        return response()->json($simulations->status($request->session()->getId()));
    }
}
