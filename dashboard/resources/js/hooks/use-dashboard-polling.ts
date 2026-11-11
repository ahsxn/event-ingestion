import { router } from '@inertiajs/react';
import { useEffect, useRef } from 'react';

const POLL_INTERVAL = 1500;
const SETTLING_PERIOD = 15_000;

export function useDashboardPolling(isRunning: boolean): void {
    const wasRunning = useRef(false);

    useEffect(() => {
        const settling = !isRunning && wasRunning.current;
        wasRunning.current = isRunning;

        if (!isRunning && !settling) {
            return;
        }

        const settlingEndsAt = settling ? Date.now() + SETTLING_PERIOD : null;
        const reloadMetrics = () => {

            if (isRunning && document.hidden) {
                return;
            }

            router.reload({ only: ['metrics', 'products'] });
        };

        reloadMetrics();

        const interval = window.setInterval(() => {
            if (settlingEndsAt !== null && Date.now() >= settlingEndsAt) {
                reloadMetrics();
                window.clearInterval(interval);
                return;
            }

            reloadMetrics();
        }, POLL_INTERVAL);

        return () => window.clearInterval(interval);
    }, [isRunning]);
}