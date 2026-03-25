terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ─────────────────────────────────────────
# GCS Bucket — Data Lake
# ─────────────────────────────────────────
resource "google_storage_bucket" "gdelt_lake" {
  name          = "${var.project_id}-gdelt-lake"
  location      = var.region
  force_destroy = false

  # Lifecycle: move raw files to Nearline after 30 days, delete after 90
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true

  labels = {
    project     = "gdelt-pipeline"
    environment = var.environment
  }
}

# Folder structure inside the bucket (via placeholder objects)
resource "google_storage_bucket_object" "raw_folder" {
  name    = "raw/.keep"
  bucket  = google_storage_bucket.gdelt_lake.name
  content = " "
}

resource "google_storage_bucket_object" "processed_folder" {
  name    = "processed/.keep"
  bucket  = google_storage_bucket.gdelt_lake.name
  content = " "
}

# ─────────────────────────────────────────
# BigQuery — Data Warehouse
# ─────────────────────────────────────────

# Raw dataset — landing zone from GCS
resource "google_bigquery_dataset" "gdelt_raw" {
  dataset_id    = "gdelt_raw"
  friendly_name = "GDELT Raw"
  description   = "Landing zone for raw GDELT event data loaded from GCS"
  location      = var.bq_location

  labels = {
    project     = "gdelt-pipeline"
    environment = var.environment
  }

  delete_contents_on_destroy = false
}

# Staging dataset — dbt staging models
resource "google_bigquery_dataset" "gdelt_staging" {
  dataset_id    = "gdelt_staging"
  friendly_name = "GDELT Staging"
  description   = "dbt staging models — cleaned and typed GDELT data"
  location      = var.bq_location

  labels = {
    project     = "gdelt-pipeline"
    environment = var.environment
  }

  delete_contents_on_destroy = false
}

# Mart dataset — dbt mart models for the dashboard
resource "google_bigquery_dataset" "gdelt_mart" {
  dataset_id    = "gdelt_mart"
  friendly_name = "GDELT Mart"
  description   = "dbt mart models — aggregated tables powering the dashboard"
  location      = var.bq_location

  labels = {
    project     = "gdelt-pipeline"
    environment = var.environment
  }

  delete_contents_on_destroy = false
}

# ─────────────────────────────────────────
# BigQuery External Table — Raw GDELT events
# Partitioned by EventDate, clustered by ActionGeo_CountryCode
# ─────────────────────────────────────────
resource "google_bigquery_table" "gdelt_events_raw" {
  dataset_id          = google_bigquery_dataset.gdelt_raw.dataset_id
  table_id            = "events"
  deletion_protection = false

  description = "Raw GDELT 1.0 events loaded from GCS. Partitioned by ingestion time (_PARTITIONTIME), clustered by ActionGeo_CountryCode, EventRootCode, and QuadClass for efficient dashboard queries. Day and DATEADDED fields store raw YYYYMMDD integers — cast to DATE in dbt staging."

  time_partitioning {
    type = "DAY"
    # No field specified = ingestion-time partitioning (_PARTITIONTIME)
    # DATEADDED is an INTEGER (YYYYMMDD) so cannot be used directly as partition field
    # dbt staging model will cast Day/DATEADDED to proper DATE columns
  }

  clustering = ["ActionGeo_CountryCode", "EventRootCode", "QuadClass"]

  schema = file("${path.module}/schemas/gdelt_events.json")

  labels = {
    project     = "gdelt-pipeline"
    environment = var.environment
  }
}

# ─────────────────────────────────────────
# Service Account — pipeline runner
# ─────────────────────────────────────────
resource "google_service_account" "gdelt_pipeline_sa" {
  account_id   = "gdelt-pipeline-sa"
  display_name = "GDELT Pipeline Service Account"
  description  = "Used by the ingestion pipeline and dbt to read/write GCS and BigQuery"
}

# IAM bindings for the service account
locals {
  pipeline_sa_roles = [
    "roles/storage.objectAdmin",        # Read/write GCS objects
    "roles/bigquery.dataEditor",        # Insert rows into BQ tables
    "roles/bigquery.jobUser",           # Run BQ jobs (load, query)
    "roles/bigquery.metadataViewer",    # dbt schema introspection
  ]
}

resource "google_project_iam_member" "pipeline_sa_roles" {
  for_each = toset(local.pipeline_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gdelt_pipeline_sa.email}"
}

# Service account key (stored locally — use Workload Identity in production)
resource "google_service_account_key" "pipeline_sa_key" {
  service_account_id = google_service_account.gdelt_pipeline_sa.name
}

resource "local_sensitive_file" "pipeline_sa_key_file" {
  content  = base64decode(google_service_account_key.pipeline_sa_key.private_key)
  filename = "${path.module}/../keys/gdelt-pipeline-sa.json"
}
