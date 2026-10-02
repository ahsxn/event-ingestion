import { router } from '@inertiajs/react';
import { useEffect } from 'react';

const POLL_INTERVAL = 1500;

export function useDashboardPolling(): void {
    useEffect(() => {
        const interval = window.setInterval(() => {
            router.reload({
                only: ['metrics', 'products'],
            });
        }, POLL_INTERVAL);

        return () => window.clearInterval(interval);
    }, []);
}