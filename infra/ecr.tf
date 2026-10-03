resource "aws_ecr_repository" "worker" {
  name = "event-ingestion-worker"

  image_tag_mutability = "MUTABLE"

  force_delete = true
}

output "worker_repository_url" {
  value = aws_ecr_repository.worker.repository_url
}
