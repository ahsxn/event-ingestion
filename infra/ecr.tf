resource "aws_ecr_repository" "worker" {
  name = "event-ingestion-worker"

  image_tag_mutability = "MUTABLE"
}

output "worker_repository_url" {
  value = aws_ecr_repository.worker.repository_url
}
