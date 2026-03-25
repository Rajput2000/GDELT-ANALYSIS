variable "project_id" {
  description = "Your GCP project ID (e.g. my-gdelt-project-123)"
  type        = string
}

variable "region" {
  description = "GCP region for GCS bucket and Dataproc (e.g. us-central1)"
  type        = string
  default     = "us-central1"
}

variable "bq_location" {
  description = "BigQuery dataset location. Use multi-region (US/EU) for best performance."
  type        = string
  default     = "US"
}

variable "environment" {
  description = "Deployment environment label (dev / staging / prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}
