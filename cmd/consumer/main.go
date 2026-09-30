package main

import (
	"context"
	"encoding/json"
	"event-ingestion/internal/events"
	"event-ingestion/internal/metrics"
	"fmt"
	"log"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/kinesis"
	"github.com/aws/aws-sdk-go-v2/service/kinesis/types"
)

const (
	streamName = "commerce-stream-events"
	shardId    = "shardId-000000000000"
)

func main() {
	ctx := context.Background()

	cfg, err := config.LoadDefaultConfig(ctx)

	if err != nil {
		log.Fatalf("load AWS config %v", err)
	}

	kinesisClient := kinesis.NewFromConfig(cfg)

	iteratorOutput, err := kinesisClient.GetShardIterator(ctx, &kinesis.GetShardIteratorInput{
		StreamName:        aws.String(streamName),
		ShardId:           aws.String(shardId),
		ShardIteratorType: types.ShardIteratorTypeTrimHorizon,
	})

	if err != nil {
		log.Fatalf("get shard iterator %v", err)
	}

	iterator := iteratorOutput.ShardIterator

	for iterator != nil {
		result, err := kinesisClient.GetRecords(ctx, &kinesis.GetRecordsInput{ShardIterator: iterator})

		if err != nil {
			log.Fatalf("get records %v", err)
		}

		for _, record := range result.Records {
			fmt.Printf(
				"sequence=%s partion_key=%s\n",
				aws.ToString(record.SequenceNumber),
				aws.ToString(record.PartitionKey),
			)

			var event events.Event

			if err := json.Unmarshal(record.Data, &event); err != nil {
				log.Fatalf("decode event: %v", err)
			}

			updates, err := metrics.FromEvent(event)

			if err != nil {
				log.Printf("aggregate events %s: %v", event.ID, err)
				continue
			}

			for _, update := range updates {
				fmt.Printf(
					"metric=%s dimension=%s value=%d timestamp=%s\n",
					update.Metric,
					update.Dimension,
					update.Value,
					update.Timestamp,
				)
			}

			// fmt.Printf(
			// 	"id:%s type:%s timestamp:%s ",
			// 	event.ID,
			// 	event.Type,
			// 	event.Timestamp.Format(time.RFC3339),
			// )

			// switch event.Type {
			// case "product_viewed":
			// 	var payload events.ProductViewed

			// 	if err := json.Unmarshal(event.Data, &payload); err != nil {
			// 		log.Fatalf("decode product_viewed %v", err)
			// 	}

			// 	fmt.Printf("product_id:%s\n\n", payload.ProductId)

			// default:
			// 	fmt.Printf("unsupported event type: %s", event.Type)
			// }
		}

		iterator = result.NextShardIterator

		time.Sleep(time.Second)
	}
}
