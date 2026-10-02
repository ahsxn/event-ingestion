const steps = [
    {
        name: 'API Gateway',
        description: 'HTTP ingestion',
    },
    {
        name: 'Lambda',
        description: 'Validate & publish',
    },
    {
        name: 'Kinesis',
        description: 'Event stream',
    },
    {
        name: 'ECS Worker',
        description: 'Aggregate',
    },
    {
        name: 'DynamoDB',
        description: 'Metrics',
    },
];

export function Pipeline() {
    return (
        <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
            <div className="mb-5">
                <div className="flex items-center gap-2">
                    <span className="h-2 w-2 rounded-full bg-emerald-500" />

                    <h2 className="font-semibold text-gray-900">
                        Event pipeline
                    </h2>
                </div>

                <p className="mt-1 text-sm text-gray-500">
                    Events are accepted synchronously and processed
                    asynchronously.
                </p>
            </div>

            <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
                {steps.map((step, index) => (
                    <div key={step.name} className="contents">
                        <div className="flex flex-1 items-center gap-3 rounded-lg border border-gray-200 bg-gray-50 px-4 py-4">
                            <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-gray-900 font-mono text-xs text-white">
                                {index + 1}
                            </div>

                            <div>
                                <div className="text-sm font-medium text-gray-900">
                                    {step.name}
                                </div>

                                <div className="text-xs text-gray-500">
                                    {step.description}
                                </div>
                            </div>
                        </div>

                        {index < steps.length - 1 && (
                            <div className="text-center text-gray-300 lg:px-1">
                                →
                            </div>
                        )}
                    </div>
                ))}
            </div>

            <div className="mt-5 grid gap-4 border-t border-gray-100 pt-5 text-sm md:grid-cols-2">
                <div>
                    <div className="font-medium text-gray-900">
                        Ingestion
                    </div>

                    <p className="mt-1 text-gray-500">
                        Lambda returns HTTP 202 once the validated
                        event has been published to Kinesis.
                    </p>
                </div>

                <div>
                    <div className="font-medium text-gray-900">
                        Processing
                    </div>

                    <p className="mt-1 text-gray-500">
                        The ECS worker consumes events and applies
                        idempotent metric updates to DynamoDB.
                    </p>
                </div>
            </div>
        </section>
    );
}