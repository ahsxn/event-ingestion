package metrics

import (
	"encoding/json"
	"event-ingestion/internal/events"
	"fmt"
	"time"
)

type Name string

const (
	ProductViews Name = "product_views"
	CartAdds     Name = "cart_adds"
	CartItems    Name = "cart_items"
	Orders       Name = "orders"
	Revenue      Name = "revenue"
)

const OverallDimensions = "all"

type Update struct {
	Metric    Name
	Dimension string
	Timestamp time.Time
	Value     int64
}

type Aggregator func(events.Event) ([]Update, error)

var aggregators = map[events.Type]Aggregator{
	events.ProductViewed:  aggregatorProductViewed,
	events.CartItemAdded:  aggregateCarItemAdded,
	events.OrderCompleted: aggregateOrderCompleted,
}

func FromEvent(event events.Event) ([]Update, error) {
	aggregator, ok := aggregators[event.Type]

	if !ok {
		return nil, fmt.Errorf("unsupported event type %s", event.Type)
	}

	return aggregator(event)
}

func productDimensions(productId string) string {
	return "product:" + productId
}

func aggregatorProductViewed(event events.Event) ([]Update, error) {
	var data events.ProductViewedData

	if err := json.Unmarshal(event.Data, &data); err != nil {
		return nil, fmt.Errorf("decode product viewed data %w", err)
	}

	return []Update{
		{
			Metric:    ProductViews,
			Dimension: OverallDimensions,
			Timestamp: event.Timestamp,
			Value:     1,
		},
		{
			Metric:    ProductViews,
			Dimension: productDimensions(data.ProductId),
			Timestamp: event.Timestamp,
			Value:     1,
		},
	}, nil
}

func aggregateCarItemAdded(event events.Event) ([]Update, error) {
	var data events.CartItemAddedData

	if err := json.Unmarshal(event.Data, &data); err != nil {
		return nil, fmt.Errorf("decode cart item added data %w", err)
	}

	quantity := int64(data.Quantity)

	return []Update{
		{
			Metric:    CartAdds,
			Dimension: OverallDimensions,
			Timestamp: event.Timestamp,
			Value:     1,
		},
		{
			Metric:    CartAdds,
			Dimension: productDimensions(data.ProductId),
			Timestamp: event.Timestamp,
			Value:     1,
		},
		{
			Metric:    CartItems,
			Dimension: productDimensions(data.ProductId),
			Timestamp: event.Timestamp,
			Value:     quantity,
		},
		{
			Metric:    CartItems,
			Dimension: OverallDimensions,
			Timestamp: event.Timestamp,
			Value:     quantity,
		},
	}, nil
}

func aggregateOrderCompleted(event events.Event) ([]Update, error) {
	var data events.OrderCompletedData

	if err := json.Unmarshal(event.Data, &data); err != nil {
		return nil, fmt.Errorf("decode order completed data %w", err)
	}

	return []Update{
		{
			Metric:    Orders,
			Dimension: OverallDimensions,
			Timestamp: event.Timestamp,
			Value:     1,
		},
		{
			Metric:    Revenue,
			Dimension: OverallDimensions,
			Timestamp: event.Timestamp,
			Value:     data.TotalPence,
		},
	}, nil
}
