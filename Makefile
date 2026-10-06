SHELL := /bin/bash

.DEFAULT_GOAL := help

INFRA_DIR := infra
AWS_INFRA_DIR := infra/aws
DASHBOARD_DIR := dashboard
BUILD_DIR := build

# Local Floci configuration
ECR_REGISTRY := localhost:4566

WORKER_REPOSITORY := $(shell cd $(INFRA_DIR) && terraform output -raw worker_repository_url 2>/dev/null)
WORKER_IMAGE := $(WORKER_REPOSITORY):dev

LOCAL_AWS := env \
	AWS_ACCESS_KEY_ID=test \
	AWS_SECRET_ACCESS_KEY=test \
	AWS_DEFAULT_REGION=us-east-1 \
	AWS_ENDPOINT_URL=http://localhost:4566 \
	aws

# Real AWS configuration
AWS_PROFILE ?= event-ingestion
AWS_REGION ?= eu-north-1

AWS_WORKER_REPOSITORY = $(shell cd $(AWS_INFRA_DIR) && AWS_PROFILE=$(AWS_PROFILE) terraform output -raw worker_repository_url 2>/dev/null)
AWS_WORKER_IMAGE = $(AWS_WORKER_REPOSITORY):dev

# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------

.PHONY: help
help:
	@echo "Available commands:"
	@echo ""
	@echo "Local infrastructure:"
	@echo "  make infra-up          Start Floci"
	@echo "  make infra-down        Stop Floci"
	@echo "  make infra-reset       Stop Floci and delete its persisted data"
	@echo ""
	@echo "Terraform:"
	@echo "  make tf-init           Initialise Terraform"
	@echo "  make tf-fmt            Format Terraform files"
	@echo "  make tf-validate       Validate Terraform configuration"
	@echo "  make tf-plan           Show Terraform changes"
	@echo "  make tf-apply          Apply Terraform changes"
	@echo "  make tf-destroy        Destroy Terraform-managed resources"
	@echo ""
	@echo "Go:"
	@echo "  make test              Run Go tests"
	@echo "  make ingest-build      Build Lambda function.zip"
	@echo ""
	@echo "Worker:"
	@echo "  make worker-build      Build worker Docker image"
	@echo "  make worker-push       Push worker image to local ECR"
	@echo "  make worker-deploy     Build, push and restart ECS worker"
	@echo ""
	@echo "Dashboard:"
	@echo "  make dashboard         Run Laravel development server"
	@echo "  make frontend          Run Vite development server"
	@echo ""
	@echo "Utilities:"
	@echo "  make api-url           Show local event ingestion URL"
	@echo "  make status            Show local infrastructure status"


# ------------------------------------------------------------------------------
# Local infrastructure
# ------------------------------------------------------------------------------

.PHONY: infra-up
infra-up:
	docker compose up -d floci

.PHONY: infra-down
infra-down:
	docker compose down

.PHONY: infra-reset
infra-reset:
	docker compose down -v


# ------------------------------------------------------------------------------
# Terraform
# ------------------------------------------------------------------------------

.PHONY: tf-init
tf-init:
	cd $(INFRA_DIR) && terraform init

.PHONY: tf-fmt
tf-fmt:
	cd $(INFRA_DIR) && terraform fmt -recursive

.PHONY: tf-validate
tf-validate:
	cd $(INFRA_DIR) && terraform validate

.PHONY: tf-plan
tf-plan:
	cd $(INFRA_DIR) && terraform plan

.PHONY: tf-apply
tf-apply:
	cd $(INFRA_DIR) && terraform apply

.PHONY: tf-destroy
tf-destroy:
	cd $(INFRA_DIR) && terraform destroy


# ------------------------------------------------------------------------------
# Go
# ------------------------------------------------------------------------------

.PHONY: test
test:
	go test ./...

.PHONY: ingest-build
ingest-build:
	mkdir -p $(BUILD_DIR)/ingest
	rm -f $(BUILD_DIR)/ingest/function.zip
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
		go build \
		-tags lambda.norpc \
		-o $(BUILD_DIR)/ingest/bootstrap \
		./cmd/ingest
	cd $(BUILD_DIR)/ingest && zip -j function.zip bootstrap


# ------------------------------------------------------------------------------
# Worker image
# ------------------------------------------------------------------------------

.PHONY: ecr-login
ecr-login:
	$(LOCAL_AWS) ecr get-login-password \
		| docker login \
			--username AWS \
			--password-stdin \
			$(ECR_REGISTRY)

.PHONY: worker-build
worker-build:
	@test -n "$(WORKER_REPOSITORY)" || \
		(echo "Worker ECR repository not found. Run 'make tf-apply' first." && exit 1)
	docker build \
		-f Dockerfile.worker \
		-t $(WORKER_IMAGE) \
		.

.PHONY: worker-push
worker-push: ecr-login
	@test -n "$(WORKER_REPOSITORY)" || \
		(echo "Worker ECR repository not found. Run 'make tf-apply' first." && exit 1)
	docker push $(WORKER_IMAGE)

.PHONY: worker-deploy
worker-deploy: worker-build worker-push
	$(LOCAL_AWS) ecs update-service \
		--cluster event-ingestion \
		--service event-ingestion-worker \
		--force-new-deployment


# ------------------------------------------------------------------------------
# Dashboard
# ------------------------------------------------------------------------------

.PHONY: dashboard
dashboard:
	cd $(DASHBOARD_DIR) && \
		php artisan serve --host=0.0.0.0 --port=8000

.PHONY: frontend
frontend:
	cd $(DASHBOARD_DIR) && \
		npm run dev -- --host=0.0.0.0


# ------------------------------------------------------------------------------
# Utilities
# ------------------------------------------------------------------------------

.PHONY: api-url
api-url:
	@cd $(INFRA_DIR) && terraform output -raw local_events_url
	@echo ""

.PHONY: status
status:
	@echo "=== Docker ==="
	@docker compose ps
	@echo ""
	@echo "=== Kinesis ==="
	@$(LOCAL_AWS) kinesis list-streams --output table
	@echo ""
	@echo "=== DynamoDB ==="
	@$(LOCAL_AWS) dynamodb list-tables --output table
	@echo ""
	@echo "=== ECS ==="
	@$(LOCAL_AWS) ecs list-tasks \
		--cluster event-ingestion \
		--output table
	@echo ""
	@echo "=== CloudWatch Logs ==="
	@$(LOCAL_AWS) logs describe-log-groups \
		--query 'logGroups[*].logGroupName' \
		--output table

# ------------------------------------------------------------------------------
# Real AWS Terraform
# ------------------------------------------------------------------------------

.PHONY: aws-tf-init
aws-tf-init:
	cd $(AWS_INFRA_DIR) && \
		AWS_PROFILE=$(AWS_PROFILE) \
		AWS_REGION=$(AWS_REGION) \
		TF_VAR_aws_region=$(AWS_REGION) \
		terraform init \
			-reconfigure \
			-backend-config=backend.hcl

.PHONY: aws-tf-fmt
aws-tf-fmt:
	cd $(AWS_INFRA_DIR) && terraform fmt -recursive

.PHONY: aws-tf-validate
aws-tf-validate:
	cd $(AWS_INFRA_DIR) && \
		AWS_PROFILE=$(AWS_PROFILE) \
		AWS_REGION=$(AWS_REGION) \
		TF_VAR_aws_region=$(AWS_REGION) \
		terraform validate

.PHONY: aws-tf-plan
aws-tf-plan:
	cd $(AWS_INFRA_DIR) && \
		AWS_PROFILE=$(AWS_PROFILE) \
		AWS_REGION=$(AWS_REGION) \
		TF_VAR_aws_region=$(AWS_REGION) \
		terraform plan

.PHONY: aws-tf-apply
aws-tf-apply:
	cd $(AWS_INFRA_DIR) && \
		AWS_PROFILE=$(AWS_PROFILE) \
		AWS_REGION=$(AWS_REGION) \
		TF_VAR_aws_region=$(AWS_REGION) \
		terraform apply

.PHONY: aws-ecr-login
aws-ecr-login:
	@test -n "$(AWS_WORKER_REPOSITORY)" || \
		(echo "Real AWS worker ECR repository not found." && exit 1)
	AWS_PROFILE=$(AWS_PROFILE) \
	aws ecr get-login-password \
		--region $(AWS_REGION) \
		| docker login \
			--username AWS \
			--password-stdin \
			$$(echo "$(AWS_WORKER_REPOSITORY)" | cut -d/ -f1)

.PHONY: aws-worker-build
aws-worker-build:
	@test -n "$(AWS_WORKER_REPOSITORY)" || \
		(echo "Real AWS worker ECR repository not found." && exit 1)
	docker build \
		-f Dockerfile.worker \
		-t $(AWS_WORKER_IMAGE) \
		.

.PHONY: aws-worker-push
aws-worker-push: aws-ecr-login
	@test -n "$(AWS_WORKER_REPOSITORY)" || \
		(echo "Real AWS worker ECR repository not found." && exit 1)
	docker push $(AWS_WORKER_IMAGE)

# .PHONY: aws-worker-image
# aws-worker-image: aws-worker-build aws-worker-push

.PHONY: aws-worker-deploy
aws-worker-deploy: aws-worker-push
	AWS_PROFILE=$(AWS_PROFILE) \
	aws ecs update-service \
		--cluster event-ingestion \
		--service event-ingestion-worker \
		--force-new-deployment \
		--region $(AWS_REGION) \
		--no-cli-pager