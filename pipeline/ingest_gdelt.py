"""
GDELT Daily Ingestion Script
────────────────────────────
Downloads the last N days of GDELT 1.0 daily event files,
unzips them, and uploads the raw CSVs to GCS under:

  gs://<bucket>/raw/YYYY/MM/DD/<YYYYMMDD>.export.CSV

Then loads each CSV from GCS into the BigQuery raw table
using a load job (append, ingestion-time partitioned).

Usage:
  python ingest_gdelt.py                        # yesterday only (normal daily run)
  python ingest_gdelt.py --days 30              # backfill last 30 days
  python ingest_gdelt.py --date 2025-03-01      # specific date
  python ingest_gdelt.py --days 7 --gcs-only    # upload to GCS but skip BQ load
"""

import argparse
import io
import logging
import os
import sys
import zipfile
from datetime import date, datetime, timedelta
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import requests
from google.cloud import bigquery, storage
from google.oauth2 import service_account

# ─────────────────────────────────────────
# Configuration — override via env vars or CLI
# ─────────────────────────────────────────
GDELT_BASE_URL = "http://data.gdeltproject.org/events"
GCS_RAW_PREFIX = "raw"
BQ_DATASET = "gdelt_raw"
BQ_TABLE = "events"
CHUNK_SIZE = 8 * 1024 * 1024  # 8 MB streaming chunks for large files

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)


# ─────────────────────────────────────────
# GCP clients
# ─────────────────────────────────────────
def get_credentials(key_path: str | None):
    """Return GCP credentials — from key file or ADC."""
    if key_path:
        return service_account.Credentials.from_service_account_file(
            key_path,
            scopes=[
                "https://www.googleapis.com/auth/cloud-platform",
            ],
        )
    # Falls back to Application Default Credentials (gcloud auth / Workload Identity)
    return None


def get_gcs_client(credentials=None) -> storage.Client:
    return storage.Client(credentials=credentials)


def get_bq_client(project: str, credentials=None) -> bigquery.Client:
    return bigquery.Client(project=project, credentials=credentials)


# ─────────────────────────────────────────
# GDELT download helpers
# ─────────────────────────────────────────
def gdelt_url(event_date: date) -> str:
    """Build the GDELT export ZIP URL for a given date."""
    return f"{GDELT_BASE_URL}/{event_date.strftime('%Y%m%d')}.export.CSV.zip"


def download_and_unzip(event_date: date) -> bytes:
    """
    Download the GDELT ZIP for a date and return the raw CSV bytes.
    Streams the download to avoid loading the full ZIP into memory at once.
    """
    url = gdelt_url(event_date)
    log.info(f"Downloading {url}")

    with requests.get(url, stream=True, timeout=120) as resp:
        if resp.status_code == 404:
            raise FileNotFoundError(
                f"GDELT file not found for {event_date}. "
                "Daily files are posted by 6AM EST — try again later."
            )
        resp.raise_for_status()

        # Buffer the zip into memory (files are ~5-15 MB compressed)
        zip_buffer = io.BytesIO()
        downloaded = 0
        for chunk in resp.iter_content(chunk_size=CHUNK_SIZE):
            zip_buffer.write(chunk)
            downloaded += len(chunk)

        log.info(f"Downloaded {downloaded / 1024 / 1024:.1f} MB")

    zip_buffer.seek(0)
    with zipfile.ZipFile(zip_buffer) as zf:
        csv_name = next(n for n in zf.namelist() if n.endswith(".CSV"))
        csv_bytes = zf.read(csv_name)
        log.info(f"Unzipped {csv_name} — {len(csv_bytes) / 1024 / 1024:.1f} MB")

    return csv_bytes


# ─────────────────────────────────────────
# GCS upload
# ─────────────────────────────────────────
def gcs_blob_path(event_date: date) -> str:
    """
    Build the GCS object path with date partitioning:
      raw/YYYY/MM/DD/YYYYMMDD.export.CSV
    """
    return (
        f"{GCS_RAW_PREFIX}/"
        f"{event_date.strftime('%Y')}/"
        f"{event_date.strftime('%m')}/"
        f"{event_date.strftime('%d')}/"
        f"{event_date.strftime('%Y%m%d')}.export.CSV"
    )


def upload_to_gcs(
    gcs_client: storage.Client,
    bucket_name: str,
    event_date: date,
    csv_bytes: bytes,
    overwrite: bool = False,
) -> str:
    """Upload CSV bytes to GCS. Returns the gs:// URI."""
    bucket = gcs_client.bucket(bucket_name)
    blob_path = gcs_blob_path(event_date)
    blob = bucket.blob(blob_path)

    if blob.exists() and not overwrite:
        log.info(f"Already exists, skipping upload: gs://{bucket_name}/{blob_path}")
        return f"gs://{bucket_name}/{blob_path}"

    log.info(f"Uploading to gs://{bucket_name}/{blob_path}")
    blob.upload_from_string(csv_bytes, content_type="text/csv")
    log.info(f"Upload complete ({len(csv_bytes) / 1024 / 1024:.1f} MB)")

    return f"gs://{bucket_name}/{blob_path}"


# ─────────────────────────────────────────
# BigQuery load
# ─────────────────────────────────────────
def load_to_bigquery(
    bq_client: bigquery.Client,
    project: str,
    gcs_uri: str,
    event_date: date,
) -> None:
    """
    Load a GCS CSV file into the BigQuery raw events table.
    Uses WRITE_APPEND so multiple runs of the same date are safe only
    with the --overwrite flag (handled by dedup in dbt staging).
    """
    table_ref = f"{project}.{BQ_DATASET}.{BQ_TABLE}"
    log.info(f"Loading {gcs_uri} → {table_ref}")

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        field_delimiter="\t",          # GDELT is tab-delimited despite .CSV extension
        skip_leading_rows=0,           # No header row in GDELT files
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        allow_jagged_rows=True,        # Some rows may have fewer fields
        allow_quoted_newlines=False,
        ignore_unknown_values=True,    # Tolerate extra columns in older files
        # Ingestion-time partitioning is set on the table itself (no decorator needed)
    )

    load_job = bq_client.load_table_from_uri(
        gcs_uri,
        table_ref,
        job_config=job_config,
    )

    log.info(f"BigQuery load job started: {load_job.job_id}")
    load_job.result()  # Wait for completion

    dest_table = bq_client.get_table(table_ref)
    log.info(
        f"Load complete. {load_job.output_rows} rows inserted. "
        f"Total rows in table: {dest_table.num_rows:,}"
    )


# ─────────────────────────────────────────
# Core pipeline — one date at a time
# ─────────────────────────────────────────
def process_date(
    event_date: date,
    gcs_client: storage.Client,
    bq_client: bigquery.Client,
    bucket_name: str,
    project: str,
    gcs_only: bool = False,
    overwrite: bool = False,
) -> bool:
    """
    Full pipeline for a single date:
      1. Download ZIP from GDELT
      2. Unzip to CSV bytes
      3. Upload to GCS
      4. Load from GCS into BigQuery (unless --gcs-only)

    Returns True on success, False on skipped/error.
    """
    log.info(f"{'─' * 50}")
    log.info(f"Processing date: {event_date}")

    try:
        csv_bytes = download_and_unzip(event_date)
        gcs_uri = upload_to_gcs(gcs_client, bucket_name, event_date, csv_bytes, overwrite)

        if not gcs_only:
            load_to_bigquery(bq_client, project, gcs_uri, event_date)

        log.info(f"✓ {event_date} complete")
        return True

    except FileNotFoundError as e:
        log.warning(str(e))
        return False
    except Exception as e:
        log.error(f"✗ Failed for {event_date}: {e}", exc_info=True)
        return False


# ─────────────────────────────────────────
# CLI
# ─────────────────────────────────────────
def parse_args():
    parser = argparse.ArgumentParser(
        description="Ingest GDELT daily event files into GCS and BigQuery."
    )
    parser.add_argument(
        "--project",
        default=os.environ.get("GCP_PROJECT"),
        help="GCP project ID (or set GCP_PROJECT env var)",
    )
    parser.add_argument(
        "--bucket",
        default=os.environ.get("GCS_BUCKET"),
        help="GCS bucket name (or set GCS_BUCKET env var)",
    )
    parser.add_argument(
        "--key-file",
        default=os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"),
        help="Path to service account JSON key (or set GOOGLE_APPLICATION_CREDENTIALS)",
    )
    parser.add_argument(
        "--days",
        type=int,
        default=1,
        help="Number of days to backfill ending yesterday (default: 1 = yesterday only)",
    )
    parser.add_argument(
        "--date",
        type=str,
        default=None,
        help="Process a specific date only (YYYY-MM-DD). Overrides --days.",
    )
    parser.add_argument(
        "--gcs-only",
        action="store_true",
        help="Upload to GCS only — skip BigQuery load",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Re-upload and re-load even if GCS file already exists",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    # Validate required args
    if not args.project:
        log.error("--project or GCP_PROJECT env var is required")
        sys.exit(1)
    if not args.bucket:
        log.error("--bucket or GCS_BUCKET env var is required")
        sys.exit(1)

    # Build date list
    if args.date:
        dates = [datetime.strptime(args.date, "%Y-%m-%d").date()]
    else:
        yesterday = date.today() - timedelta(days=1)
        dates = [yesterday - timedelta(days=i) for i in range(args.days)]
        dates.reverse()  # Process oldest → newest

    log.info(f"Pipeline starting — {len(dates)} date(s) to process")
    log.info(f"Project: {args.project} | Bucket: {args.bucket}")

    # Initialise GCP clients
    credentials = get_credentials(args.key_file)
    gcs_client = get_gcs_client(credentials)
    bq_client = get_bq_client(args.project, credentials)

    # Process each date
    results = {"success": 0, "skipped": 0, "failed": 0}
    for d in dates:
        ok = process_date(
            event_date=d,
            gcs_client=gcs_client,
            bq_client=bq_client,
            bucket_name=args.bucket,
            project=args.project,
            gcs_only=args.gcs_only,
            overwrite=args.overwrite,
        )
        if ok:
            results["success"] += 1
        else:
            results["failed"] += 1

    log.info(f"{'─' * 50}")
    log.info(
        f"Pipeline complete — "
        f"✓ {results['success']} succeeded  "
        f"✗ {results['failed']} failed"
    )

    if results["failed"] > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
