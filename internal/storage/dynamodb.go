package storage

import (
	"context"
	"errors"
	"event-ingestion/internal/metrics"
	"fmt"
	"strconv"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

var ErrAlreadyProcessed = errors.New("event already processed")

type Store struct {
	client                   *dynamodb.Client
	metricsTableName         string
	processedEventsTablename string
}

func New(
	client *dynamodb.Client,
	metricsTableName string,
	processedEventsTablename string,
) *Store {
	return &Store{
		client:                   client,
		metricsTableName:         metricsTableName,
		processedEventsTablename: processedEventsTablename,
	}
}

func (s *Store) ApplyEvent(
	ctx context.Context,
	eventID string,
	updates []metrics.Update,
) error {

	items := make(
		[]types.TransactWriteItem,
		0,
		len(updates)+1,
	)

	items = append(items, types.TransactWriteItem{
		Put: &types.Put{
			TableName: aws.String(s.processedEventsTablename),

			Item: map[string]types.AttributeValue{
				"event_id": &types.AttributeValueMemberS{
					Value: eventID,
				},
			},

			ConditionExpression: aws.String(
				"attribute_not_exists(event_id)",
			),
		},
	})

	for _, update := range updates {
		items = append(items, types.TransactWriteItem{
			Update: &types.Update{
				TableName: aws.String(s.metricsTableName),

				Key: map[string]types.AttributeValue{
					"metric": &types.AttributeValueMemberS{
						Value: string(update.Metric),
					},
					"dimension": &types.AttributeValueMemberS{
						Value: update.Dimension,
					},
				},

				UpdateExpression: aws.String(
					"ADD #value :increment",
				),

				ExpressionAttributeNames: map[string]string{
					"#value": "value",
				},

				ExpressionAttributeValues: map[string]types.AttributeValue{
					":increment": &types.AttributeValueMemberN{
						Value: strconv.FormatInt(update.Value, 10),
					},
				},
			},
		})
	}

	_, err := s.client.TransactWriteItems(
		ctx,
		&dynamodb.TransactWriteItemsInput{
			TransactItems: items,
		},
	)

	if err == nil {
		return nil
	}

	if isDuplicateEvent(err) {
		return ErrAlreadyProcessed
	}

	return fmt.Errorf("apply event %s: %w", eventID, err)
}

func isDuplicateEvent(err error) bool {
	var cancelled *types.TransactionCanceledException

	if !errors.As(err, &cancelled) {
		return false
	}

	if len(cancelled.CancellationReasons) == 0 {
		return false
	}

	return aws.ToString(
		cancelled.CancellationReasons[0].Code,
	) == "ConditionalCheckFailed"
}
