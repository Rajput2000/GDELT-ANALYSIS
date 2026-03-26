# GDELT Pipeline Ingestion Script

This document provides step-by-step instructions to reproduce the data ingestion pipeline that downloads GDELT 1.0 daily event files, uploads them to GCS, and loads them into BigQuery.

## Prerequisites

### Required Tools
- Python 3.10+
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- Service account key from Terraform setup (see `terraform/README.md`)

### Required Infrastructure
The following must exist before running the pipeline (created by Terraform):
- GCS bucket: `{project_id}-gdelt-lake`
- BigQuery dataset: `gdelt_raw` with `events` table
- Service account key: `../keys/gdelt-pipeline-sa.json`

## How It Works

The ingestion script performs the following for each date:

1. **Download** the GDELT daily ZIP from `data.gdeltproject.org`
2. **Unzip** the CSV in memory
3. **Upload** the raw CSV to GCS at `gs://<bucket>/raw/YYYY/MM/DD/YYYYMMDD.export.CSV`
4. **Load** the CSV from GCS into BigQuery via a load job (tab-delimited, append mode)

### GCS Partitioning
Files are stored with date-based partitioning:
```
gs://<bucket>/raw/
└── 2025/
    └── 03/
        ├── 01/20250301.export.CSV
        ├── 02/20250302.export.CSV
        └── ...
```

### BigQuery Load
- Format: tab-delimited CSV (no header row)
- Write mode: `WRITE_APPEND` (deduplication handled in dbt staging)
- Partitioning: ingestion-time (`_PARTITIONTIME`)

## Setup

### 1. Install Dependencies
```bash
cd pipeline
pip install -r requirements.txt
```

### 2. Configure Environment
```bash
cp .env.example .env
```

Edit `.env` with your values:
```bash
export GCP_PROJECT="<your-gcp-project-id>"
export GCS_BUCKET="<your-gcp-project-id>-gdelt-lake"
export GOOGLE_APPLICATION_CREDENTIALS="<path-to-service-account-key-json>"
```

Source the environment:
```bash
source .env
```

## Usage

### Daily Run (yesterday only — default)
```bash
python ingest_gdelt.py
```

### Backfill Last 30 Days
```bash
python ingest_gdelt.py --days 30
```

### Specific Date
```bash
python ingest_gdelt.py --date 2025-03-01
```

### GCS Only (skip BigQuery load)
```bash
python ingest_gdelt.py --days 7 --gcs-only
```

### Overwrite Existing Files
```bash
python ingest_gdelt.py --days 30 --overwrite
```

### CLI Reference

| Flag | Default | Description |
|---|---|---|
| `--project` | `$GCP_PROJECT` | GCP project ID |
| `--bucket` | `$GCS_BUCKET` | GCS bucket name |
| `--key-file` | `$GOOGLE_APPLICATION_CREDENTIALS` | Path to service account JSON key |
| `--days` | `1` | Number of days to backfill ending yesterday |
| `--date` | — | Process a specific date (YYYY-MM-DD), overrides `--days` |
| `--gcs-only` | `false` | Upload to GCS only, skip BigQuery load |
| `--overwrite` | `false` | Re-upload and re-load even if GCS file exists |

## File Structure

```
pipeline/
├── ingest_gdelt.py      # Main ingestion script
├── requirements.txt     # Python dependencies
├── .env.example         # Example environment variables
├── .env                 # Local environment variables (not in git)
└── README.md            # This file
```

## Troubleshooting

### Common Issues

1. **FileNotFoundError: service account key not found**
   ```
   FileNotFoundError: No such file or directory: './keys/gdelt-pipeline-sa.json'
   ```
   **Solution**: Ensure `GOOGLE_APPLICATION_CREDENTIALS` points to the correct path relative to where you run the script. The key is typically at `../keys/gdelt-pipeline-sa.json`.

2. **GDELT file not found (404)**
   ```
   GDELT file not found for 2025-03-26. Daily files are posted by 6AM EST — try again later.
   ```
   **Solution**: GDELT publishes daily files by 6AM EST. If requesting today's date, wait until after that time.

3. **Permission denied on GCS or BigQuery**
   ```
   403: does not have storage.objects.create access
   ```
   **Solution**: Verify the service account has the correct IAM roles (`storage.objectAdmin`, `bigquery.dataEditor`, `bigquery.jobUser`). Re-run `terraform apply` if needed.

### Verification Commands

```bash
# Check GCS uploads
gsutil ls gs://<your-bucket>/raw/

# Check BigQuery row count
bq query --use_legacy_sql=false 'SELECT COUNT(*) FROM gdelt_raw.events'
```

## Next Steps

After ingestion:

1. **dbt**: Run `dbt run` to build staging views and mart tables (see `dbt/README.md`)
2. **Orchestration**: Set up Kestra Cloud for daily automation (see `orchestration/`)
3. **Dashboard**: Connect Looker Studio to the mart tables
