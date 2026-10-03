package main

import (
	"context"
	"encoding/json"
	"errors"
	"event-ingestion/internal/events"
	"event-ingestion/internal/logging"
	"event-ingestion/internal/metrics"
	"event-ingestion/internal/storage"
	"fmt"
	"log"
	"log/slog"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/kinesis"
	"github.com/aws/aws-sdk-go-v2/service/kinesis/types"
)

/**
* @TODO implement Kinesis checkpoints
* currently using trim horizon, which means
* when we restart or after a crash we start from
* the first event in the stream, rather than the
* last event that was successfully consumed
 */

func main() {
	streamName := requiredEnv("KINESIS_STREAM_NAME")

	metricsTableName := requiredEnv("METRICS_TABLE_NAME")

	processedEventsTableName := requiredEnv("PROCESSED_EVENTS_TABLE_NAME")

	ctx, stop := signal.NotifyContext(
		context.Background(),
		os.Interrupt,
		syscall.SIGTERM,
	)

	defer stop()

	cfg, err := config.LoadDefaultConfig(ctx)

	if err != nil {
		log.Fatalf("load AWS config %v", err)
	}

	kinesisClient := kinesis.NewFromConfig(cfg)

	dynamodbClient := dynamodb.NewFromConfig(cfg)

	metricStore := storage.New(
		dynamodbClient,
		metricsTableName,
		processedEventsTableName,
	)

	logger := logging.New("worker")

	shards, err := listShards(ctx, kinesisClient, streamName)

	if err != nil {
		log.Fatalf("list shards %v", err)
	}

	if len(shards) == 0 {
		log.Fatalf("stream has no shards")
	}

	log.Printf("found %d shards", len(shards))

	var wg sync.WaitGroup

	errCh := make(chan error, len(shards))

	for _, shard := range shards {
		shardId := aws.ToString(shard.ShardId)

		wg.Add(1)

		go func() {
			defer wg.Done()

			logger.Info(
				"shard consumer started",
				"shard_id", shardId,
			)

			err := consumeShard(ctx, logger, kinesisClient, metricStore, streamName, shardId)

			if err != nil && !errors.Is(err, context.Canceled) {
				errCh <- fmt.Errorf(
					"consume shard %s: %w",
					shardId,
					err,
				)
			}

			logger.Info(
				"shard consumer stopped",
				"shard_id", shardId,
			)
		}()
	}

	select {
	case <-ctx.Done():
		logger.Info("shutdown requested")

	case err := <-errCh:
		logger.Error(
			"wokrer failed",
			"error", err,
		)
		stop()
	}

	wg.Wait()

	logger.Info("worker stopped")
}

func listShards(ctx context.Context, client *kinesis.Client, streamName string) ([]types.Shard, error) {
	result, err := client.ListShards(
		ctx,
		&kinesis.ListShardsInput{
			StreamName: aws.String(streamName),
		},
	)

	if err != nil {
		return nil, fmt.Errorf("list shards: %w", err)
	}

	return result.Shards, nil
}

func consumeShard(
	ctx context.Context,
	logger *slog.Logger,
	client *kinesis.Client,
	store *storage.Store,
	streamName string,
	shardId string,
) error {
	result, err := client.GetShardIterator(
		ctx, &kinesis.GetShardIteratorInput{
			StreamName:        aws.String(streamName),
			ShardId:           aws.String(shardId),
			ShardIteratorType: types.ShardIteratorTypeTrimHorizon,
		},
	)

	if err != nil {
		return fmt.Errorf("get shared iterator %w", err)
	}

	iterator := result.ShardIterator

	for iterator != nil {
		result, err := client.GetRecords(
			ctx,
			&kinesis.GetRecordsInput{
				ShardIterator: iterator,
			},
		)

		if err != nil {
			return fmt.Errorf("get records %w", err)
		}

		for _, record := range result.Records {
			if err := processRecord(ctx, logger, store, record); err != nil {
				return err
			}

		}

		iterator = result.NextShardIterator

		if err := sleep(ctx, time.Second); err != nil {
			return err
		}
	}

	return nil
}

func processRecord(ctx context.Context, logger *slog.Logger, store *storage.Store, record types.Record) error {
	var event events.Event

	if err := json.Unmarshal(record.Data, &event); err != nil {
		return fmt.Errorf("decode event %w", err)
	}

	updates, err := metrics.FromEvent(event)

	if err != nil {
		return fmt.Errorf("aggregate event id=%s %w", event.ID, err)
	}

	err = store.ApplyEvent(ctx, event.ID, updates)

	if errors.Is(err, storage.ErrAlreadyProcessed) {
		log.Printf("skip duplicate event id = %s", event.ID)
		return nil
	}

	if err != nil {
		return fmt.Errorf("persist event id %s %w", event.ID, err)
	}

	logger.Info(
		"event processed",
		"event_id", event.ID,
		"event_type", event.Type,
		"sequence_number", aws.ToString(record.SequenceNumber),
		"metrics", len(updates),
	)

	return nil
}

func sleep(ctx context.Context, duration time.Duration) error {
	select {
	case <-time.After(duration):
		return nil

	case <-ctx.Done():
		return ctx.Err()
	}
}

func requiredEnv(name string) string {
	value, ok := os.LookupEnv(name)

	if !ok || value == "" {
		log.Fatalf("%s is required", name)
	}

	return value
}
