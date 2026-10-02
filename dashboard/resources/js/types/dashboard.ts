export type Metrics = {
    product_views: number;
    cart_adds: number;
    orders: number;
    revenue: number;
    average_order_value: number;
    cart_view_ratio: number;
};

export type Product = {
    product: string;
    views: number;
    cart_adds: number;
    cart_view_ratio: number;
};

export type DashboardProps = {
    metrics: Metrics;
    products: Product[];
};