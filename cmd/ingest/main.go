package main

import (
	"context"
	"encoding/json"
	"log"
	"log/slog"
	"os"

	domainevents "event-ingestion/internal/events"
	"event-ingestion/internal/logging"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/kinesis"
)

type Handler struct {
	kinesis    *kinesis.Client
	streamName string
	logger     *slog.Logger
}

func main() {
	ctx := context.Background()

	cfg, err := config.LoadDefaultConfig(ctx)

	if err != nil {
		log.Fatalf("load aws config %v", err)
	}

	streamName := os.Getenv("KINESIS_STREAM_NAME")

	if streamName == "" {
		log.Fatal("KINESIS_STREAM_NAME is required")
	}

	logger := logging.New("ingest")

	handler := Handler{
		kinesis:    kinesis.NewFromConfig(cfg),
		streamName: streamName,
		logger:     logger,
	}

	lambda.Start(handler.Handle)
}

func (h *Handler) Handle(
	ctx context.Context,
	request events.APIGatewayV2HTTPRequest,
) (events.APIGatewayV2HTTPResponse, error) {
	var event domainevents.Event

	if err := json.Unmarshal([]byte(request.Body), &event); err != nil {
		return response(400, `{"error": "invalid json"}`), nil
	}

	if err := domainevents.Validate(event); err != nil {
		body, _ := json.Marshal(map[string]string{
			"error": err.Error(),
		})

		return response(400, string(body)), nil
	}

	data, err := json.Marshal(event)

	if err != nil {
		h.logger.Error(
			"failed to encode event",
			"event id", event.ID,
			"error", err,
		)

		return response(500, `{"error":"internal error"}`), nil
	}

	_, err = h.kinesis.PutRecord(
		ctx,
		&kinesis.PutRecordInput{
			StreamName:   aws.String(h.streamName),
			PartitionKey: aws.String(event.ID),
			Data:         data,
		},
	)

	if err != nil {
		h.logger.Error(
			"failed to publish event",
			"event id", event.ID,
			"error", err,
		)

		return response(500, `{"error":"failed to publish event"}`), nil
	}

	h.logger.Info(
		"event accepted",
		"event_id", event.ID,
		"event_type", event.Type,
	)

	return response(202, `{"status":"accepted"}`), nil
}

func response(statusCode int, body string) events.APIGatewayV2HTTPResponse {
	return events.APIGatewayV2HTTPResponse{
		StatusCode: statusCode,
		Headers: map[string]string{
			"content-type": "application/json",
		},
		Body: body,
	}
}
