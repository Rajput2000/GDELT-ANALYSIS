output "gcs_bucket_name" {
  description = "Name of the GDELT data lake GCS bucket"
  value       = google_storage_bucket.gdelt_lake.name
}

output "gcs_bucket_url" {
  description = "GCS URL of the data lake bucket"
  value       = "gs://${google_storage_bucket.gdelt_lake.name}"
}

output "bq_raw_dataset" {
  description = "BigQuery raw dataset ID"
  value       = google_bigquery_dataset.gdelt_raw.dataset_id
}

output "bq_staging_dataset" {
  description = "BigQuery staging dataset ID"
  value       = google_bigquery_dataset.gdelt_staging.dataset_id
}

output "bq_mart_dataset" {
  description = "BigQuery mart dataset ID"
  value       = google_bigquery_dataset.gdelt_mart.dataset_id
}

output "pipeline_service_account_email" {
  description = "Service account email used by the pipeline"
  value       = google_service_account.gdelt_pipeline_sa.email
}

output "pipeline_sa_key_path" {
  description = "Local path to the service account JSON key"
  value       = local_sensitive_file.pipeline_sa_key_file.filename
  sensitive   = true
}
