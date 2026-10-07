variable "aws_region" {
  type        = string
  description = "AWS region used by the demo deployment"
  default     = "eu-north-1"
}

variable "services_enabled" {
  type        = bool
  description = "Whether ECS application services should be running"
  default     = true
}
