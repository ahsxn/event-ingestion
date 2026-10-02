import { router } from '@inertiajs/react';
import { useState } from 'react';

const events = [
    {
        type: 'product_viewed',
        label: 'Product View',
        description: 'Generate a product view event',
    },
    {
        type: 'cart_item_added',
        label: 'Add to Cart',
        description: 'Generate a cart item event',
    },
    {
        type: 'order_completed',
        label: 'Complete Order',
        description: 'Generate an order and revenue event',
    },
];

export function EventActions() {
    const [sending, setSending] = useState<string | null>(null);
    const [status, setStatus] = useState<string | null>(null);

    function sendEvent(type: string) {
        setSending(type);
        setStatus(null);

        router.post(
            `/demo-events/${type}`,
            {},
            {
                preserveScroll: true,

                onSuccess: () => {
                    setStatus(
                        `${type} accepted into the event stream`,
                    );
                },

                onError: () => {
                    setStatus('Failed to submit event');
                },

                onFinish: () => {
                    setSending(null);
                },
            },
        );
    }

    return (
        <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
            <div className="mb-5">
                <h2 className="font-semibold text-gray-900">
                    Send demo event
                </h2>

                <p className="mt-1 text-sm text-gray-500">
                    Submit events through the same ingestion endpoint
                    used by an application client.
                </p>
            </div>

            <div className="grid gap-3 md:grid-cols-3">
                {events.map((event) => (
                    <button
                        key={event.type}
                        type="button"
                        disabled={sending !== null}
                        onClick={() => sendEvent(event.type)}
                        className="rounded-lg border border-gray-200 bg-gray-50 p-4 text-left transition hover:border-gray-300 hover:bg-gray-100 disabled:cursor-not-allowed disabled:opacity-50"
                    >
                        <div className="font-medium text-gray-900">
                            {sending === event.type
                                ? 'Sending...'
                                : event.label}
                        </div>

                        <div className="mt-1 text-sm text-gray-500">
                            {event.description}
                        </div>

                        <div className="mt-3 font-mono text-xs text-gray-400">
                            {event.type}
                        </div>
                    </button>
                ))}
            </div>

            {status && (
                <div className="mt-4 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">
                    {status}

                    <span className="ml-2 text-emerald-600">
                        Processing continues asynchronously.
                    </span>
                </div>
            )}
        </section>
    );
}