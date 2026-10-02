type Props = {
    label: string;
    value: string;
    description?: string;
};

export function MetricCard({
    label,
    value,
    description,
}: Props) {
    return (
        <div className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
            <div className="text-sm font-medium text-gray-500">
                {label}
            </div>

            <div className="mt-2 text-3xl font-semibold tracking-tight text-gray-900 tabular-nums">
                {value}
            </div>

            {description && (
                <div className="mt-2 text-xs text-gray-400">
                    {description}
                </div>
            )}
        </div>
    );
}