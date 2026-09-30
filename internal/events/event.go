package events

import (
	"encoding/json"
	"time"
)

type Type string

const (
	ProductViewed  Type = "product_viewed"
	CartItemAdded  Type = "cart_item_added"
	OrderCompleted Type = "order_completed"
)

type Event struct {
	ID        string          `json:"id"`
	Type      Type            `json:"type"`
	Timestamp time.Time       `json:"timestamp"`
	Data      json.RawMessage `json:"data"`
}

type ProductViewedData struct {
	ProductId string `json:"product_id"`
}

type CartItemAddedData struct {
	ProductId string `json:"product_id"`
	Quantity  int    `json:"quantity"`
}

type OrderCompletedData struct {
	OrderId    string `json:"order_id"`
	TotalPence int64  `json:"total_pence"`
}
