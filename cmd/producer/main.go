package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/kinesis"

	"event-ingestion/internal/events"
)

const streamName = "commerce-stream-events"

func main() {
	if len(os.Args) < 2 {
		log.Fatalf(
			"usage: go run ./cmd/producer <%s|%s|%s>",
			events.ProductViewed,
			events.CartItemAdded,
			events.OrderCompleted,
		)
	}

	eventType := events.Type(os.Args[1])

	event, err := buildEvent(eventType)

	if err != nil {
		log.Fatal(err)
	}

	data, err := json.Marshal(event)

	if err != nil {
		log.Fatalf("encode event %v", err)
	}

	ctx := context.Background()

	cfg, err := config.LoadDefaultConfig(ctx)

	if err != nil {
		log.Fatalf("load AWS config %v", err)
	}

	client := kinesis.NewFromConfig(cfg)

	result, err := client.PutRecord(ctx, &kinesis.PutRecordInput{
		StreamName:   aws.String(streamName),
		PartitionKey: aws.String(event.ID),
		Data:         data,
	})

	if err != nil {
		log.Fatalf("put kinesis record %v", err)
	}

	fmt.Printf("Published %s\n", string(data))
	fmt.Printf("Shard %s\n", aws.ToString(result.ShardId))
	fmt.Printf("Sequence number %s\n", aws.ToString(result.SequenceNumber))
}

func buildEvent(eventType events.Type) (events.Event, error) {
	var payload any

	switch eventType {
	case events.ProductViewed:
		payload = events.ProductViewedData{
			ProductId: "prod_123",
		}

	case events.CartItemAdded:
		payload = events.CartItemAddedData{
			ProductId: "prod_123",
			Quantity:  2,
		}
	case events.OrderCompleted:
		payload = events.OrderCompletedData{
			OrderId:    fmt.Sprintf("ord-%d", time.Now().UnixNano()),
			TotalPence: 8999,
		}
	default:
		return events.Event{}, fmt.Errorf("unsupported event type: %s", eventType)
	}

	data, err := json.Marshal(payload)

	if err != nil {
		return events.Event{}, fmt.Errorf("encode payload %w", err)
	}

	return events.Event{
		ID:        fmt.Sprintf("evt-%d", time.Now().UnixNano()),
		Type:      eventType,
		Timestamp: time.Now().UTC(),
		Data:      data,
	}, nil
}
