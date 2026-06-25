variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "enable_logging" {
  description = "Enable access logging to S3"
  type        = bool
  default     = true
}
