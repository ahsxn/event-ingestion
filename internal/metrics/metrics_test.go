package metrics_test

import (
	"encoding/json"
	"event-ingestion/internal/events"
	"event-ingestion/internal/metrics"
	"reflect"
	"testing"
	"time"
)

func TestFromEvent(t *testing.T) {
	timestamp := time.Date(
		2026, time.September, 30,
		18, 0, 0, 0,
		time.UTC,
	)

	tests := []struct {
		name     string
		event    events.Event
		expected []metrics.Update
	}{
		{
			name: "product_viewed",
			event: newEvent(
				t,
				events.ProductViewed,
				timestamp,
				events.ProductViewedData{
					ProductId: "prod_123",
				},
			),
			expected: []metrics.Update{
				{
					Metric:    metrics.ProductViews,
					Dimension: metrics.OverallDimensions,
					Timestamp: timestamp,
					Value:     1,
				},
				{
					Metric:    metrics.ProductViews,
					Dimension: "product:prod_123",
					Timestamp: timestamp,
					Value:     1,
				},
			},
		},
		{
			name: "cart item added",
			event: newEvent(
				t,
				events.CartItemAdded,
				timestamp,
				events.CartItemAddedData{
					ProductId: "prod_123",
					Quantity:  3,
				},
			),
			expected: []metrics.Update{
				{
					Metric:    metrics.CartAdds,
					Dimension: metrics.OverallDimensions,
					Timestamp: timestamp,
					Value:     1,
				},
				{
					Metric:    metrics.CartAdds,
					Dimension: "product:prod_123",
					Timestamp: timestamp,
					Value:     1,
				},
				{
					Metric:    metrics.CartItems,
					Dimension: "product:prod_123",
					Timestamp: timestamp,
					Value:     3,
				},
				{
					Metric:    metrics.CartItems,
					Dimension: metrics.OverallDimensions,
					Timestamp: timestamp,
					Value:     3,
				},
			},
		},
		{
			name: "order completed",
			event: newEvent(
				t,
				events.OrderCompleted,
				timestamp,
				events.OrderCompletedData{
					OrderId:    "ord_123",
					TotalPence: 8999,
				},
			),
			expected: []metrics.Update{
				{
					Metric:    metrics.Orders,
					Dimension: metrics.OverallDimensions,
					Timestamp: timestamp,
					Value:     1,
				},
				{
					Metric:    metrics.Revenue,
					Dimension: metrics.OverallDimensions,
					Timestamp: timestamp,
					Value:     8999,
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			actual, err := metrics.FromEvent(tt.event)

			if err != nil {
				t.Fatalf("FromEvent error %v", err)
			}

			if !reflect.DeepEqual(actual, tt.expected) {
				t.Errorf(
					"FromEvent = %#v expected %#v",
					actual,
					tt.expected,
				)
			}
		})
	}
}

func TestFromEventRejectsUnsupportedEvent(t *testing.T) {
	event := events.Event{
		ID:   "evt_test",
		Type: events.Type("something_unknown"),
	}

	_, err := metrics.FromEvent(event)

	if err == nil {
		t.Fatal("expected error, got nil")
	}
}

func TestFromEventRejectsInvalidData(t *testing.T) {
	event := events.Event{
		ID:        "evt_test",
		Type:      events.ProductViewed,
		Timestamp: time.Now().UTC(),
		Data:      json.RawMessage(`{"product_id":`),
	}

	_, err := metrics.FromEvent(event)

	if err == nil {
		t.Fatal("expected error, got nil")
	}
}

func newEvent(
	t *testing.T,
	eventType events.Type,
	timestamp time.Time,
	data any,
) events.Event {
	t.Helper()

	payload, err := json.Marshal(data)

	if err != nil {
		t.Fatalf("marshal event data %v", err)
	}

	return events.Event{
		ID:        "evt_test",
		Type:      eventType,
		Timestamp: timestamp,
		Data:      payload,
	}
}
