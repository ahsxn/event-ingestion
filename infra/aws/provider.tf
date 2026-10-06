provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "event-ingestion"
      Environment = "portfolio"
      ManagedBy   = "terraform"
    }
  }
}
