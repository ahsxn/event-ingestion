import axios from 'axios';

type RouteRequest = {
    url: string;
    method: string;
};

export class SimulationRequestError extends Error {
    readonly status: number;

    constructor(status: number, message: string) {
        super(message);
        this.status = status;
    }
}

export const simulationHttp = axios.create({
    withCredentials: true,
    withXSRFToken: true,
    xsrfCookieName: 'XSRF-TOKEN',
    xsrfHeaderName: 'X-XSRF-TOKEN',
    headers: {
        Accept: 'application/json',
    },
});

export async function simulationRequest<T>(
    route: RouteRequest,
    body?: object,
): Promise<T> {
    try {
        const response = await simulationHttp.request<T>({
            url: route.url,
            method: route.method,
            data: body,
        });

        return response.data;
    } catch (cause) {
        if (!axios.isAxiosError(cause)) {
            throw cause;
        }

        const payload: unknown = cause.response?.data;
        let message: string | undefined;

        if (payload && typeof payload === 'object') {
            const details = payload as { message?: unknown; error?: unknown };

            message =
                typeof details.message === 'string'
                    ? details.message
                    : typeof details.error === 'string'
                      ? details.error
                      : undefined;
        }

        throw new SimulationRequestError(
            cause.response?.status ?? 0,
            message ?? cause.message ?? 'Simulation request failed.',
        );
    }
}