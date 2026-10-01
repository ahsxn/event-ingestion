package events

import (
	"encoding/json"
	"fmt"
)

func Validate(event Event) error {
	if event.ID == "" {
		return fmt.Errorf("event id is required")
	}

	if event.Timestamp.IsZero() {
		return fmt.Errorf("timestamp is required")
	}

	// figure out a better way to do this.
	switch event.Type {
	case ProductViewed:
		var data ProductViewedData

		if err := json.Unmarshal(event.Data, &data); err != nil {
			return fmt.Errorf("decode product viewed data %w", err)
		}

		if data.ProductId == "" {
			return fmt.Errorf("product_id is required")
		}
	case CartItemAdded:
		var data CartItemAddedData

		if err := json.Unmarshal(event.Data, &data); err != nil {
			return fmt.Errorf("decode cart item added data %w", err)
		}

		if data.ProductId == "" {
			return fmt.Errorf("product_id is required")
		}

		if data.Quantity <= 0 {
			return fmt.Errorf("quantity must be greater than zero")
		}
	case OrderCompleted:
		var data OrderCompletedData

		if err := json.Unmarshal(event.Data, &data); err != nil {
			return fmt.Errorf("decode order completed data %w", err)
		}

		if data.OrderId == "" {
			return fmt.Errorf("order id is required")
		}

		if data.TotalPence < 0 {
			return fmt.Errorf("total pence cannot be negative")
		}
	default:
		return fmt.Errorf("unsupported event type %s", event.Type)
	}

	return nil
}
