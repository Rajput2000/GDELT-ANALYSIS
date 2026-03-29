# 🌍 GDELT Global Event Pulse

An automated batch pipeline that ingests, transforms, and visualises 30 days of global news event data from the [GDELT Project](https://www.gdeltproject.org/), making it easy to track worldwide conflict and cooperation trends through a live dashboard.

---

## Problem Description

The world generates an enormous volume of news events every single day — conflicts, diplomatic meetings, protests, and cooperation agreements — across every country. This information exists and is publicly available, but it arrives as a raw firehose: hundreds of thousands of tab-delimited rows per day, with 58 cryptic columns, distributed across thousands of news sources.

**There is no easy way to answer questions like:**
- Is the world getting more conflicted or more cooperative right now?
- Which countries are dominating global news today?
- Is the tone of media coverage around a region improving or deteriorating?

The [GDELT 1.0 Event Database](https://www.gdeltproject.org/data.html#rawdatafiles) records every significant event reported in global news media — going back to 1979 — including who did what to whom, where, and how the media covered it. Each event is scored on the **Goldstein Scale** (stability impact, -10 to +10) and assigned an **AvgTone** (media sentiment, -100 to +100). This is extraordinarily rich data, but it is completely inaccessible to most people in its raw form.

This project solves that by building a fully automated pipeline that turns the raw GDELT firehose into a clean, queryable, and visual dataset — refreshed every morning automatically.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       Local Kestra                              │
│         (Docker Compose — daily schedule at 7AM UTC)            │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                    ┌───────▼────────┐
                    │  GDELT Project │
                    │  (HTTP source) │
                    └───────┬────────┘
                            │ Download ZIP → unzip CSV
                    ┌───────▼────────┐
                    │   GCS Bucket   │  ← Data Lake
                    │  raw/YYYY/MM/  │    (partitioned by date)
                    └───────┬────────┘
                            │ BQ Load Job (tab-delimited, append)
                    ┌───────▼────────┐
                    │   BigQuery     │  ← Data Warehouse
                    │  gdelt_raw     │    (ingestion-time partitioned)
                    └───────┬────────┘
                            │ dbt run
               ┌────────────┼────────────┐
               │            │            │
        ┌──────▼──────┐     │     ┌──────▼──────┐
        │gdelt_staging│     │     │  gdelt_mart  │
        │    (views)  │     │     │  (tables)    │
        └─────────────┘     │     └──────┬───────┘
                            │            │
                    ┌───────▼────────────▼───┐
                    │     Looker Studio      │  ← Dashboard
                    │      (live BQ)         │
                    └────────────────────────┘
```

---

## Technologies

| Layer | Tool | Purpose |
|---|---|---|
| Infrastructure as Code | [Terraform](https://www.terraform.io/) | Provision GCS bucket, BigQuery datasets, service account + IAM |
| Cloud | [GCP](https://cloud.google.com/) | GCS (data lake), BigQuery (data warehouse) |
| Orchestration | [Kestra](https://kestra.io/) (Docker Compose) | Daily scheduled pipeline — download → GCS → BigQuery → dbt |
| Data Lake | [Google Cloud Storage](https://cloud.google.com/storage) | Raw GDELT CSV files, date-partitioned |
| Data Warehouse | [BigQuery](https://cloud.google.com/bigquery) | Ingestion-time partitioned, clustered by country + event type |
| Transformations | [dbt](https://www.getdbt.com/) | Staging views + mart tables with tests |
| Dashboard | [Looker Studio](https://lookerstudio.google.com/) | Live dashboard connected to BigQuery mart |

---

## Dashboard

The dashboard answers two questions visually:

**Global Event Tone Over Time** *(temporal)*
Daily average media tone and event volume over the last 30 days, broken down by quad class (Verbal Cooperation, Material Cooperation, Verbal Conflict, Material Conflict). Reveals whether global news is trending more positive or negative.

**Top Countries by Event Activity** *(categorical)*
Bar chart of the most active countries in global news over the last 30 days, coloured by average tone. Reveals which countries are dominating coverage and whether that coverage is positive or negative.

**Most Volatile Day** *(scorecard)*
Single-value card highlighting the day with the highest conflict percentage over the last 30 days. Useful for pinpointing specific dates where global tension spiked, which can be cross-referenced against real-world news events.

**Global News Sentiment Map** *(geo chart)*
World map where each country is coloured by its average media tone — red for negative coverage, green for positive. Immediately reveals which regions are experiencing the most negative news narratives.


> 🔗 **[View the live dashboard](https://lookerstudio.google.com/reporting/1ed1c608-2d93-4040-806d-867be4332501)**

---

## Dataset

**Source:** [GDELT 1.0 Event Database](https://www.gdeltproject.org/data.html#rawdatafiles)

GDELT (Global Database of Events, Language, and Tone) monitors the world's news media and codes every event it finds using the [CAMEO taxonomy](http://gdeltproject.org/data/documentation/CAMEO.Manual.1.1b3.pdf). Daily files are published by 6AM EST, seven days a week.

Key fields used in this project:

| Field | Description |
|---|---|
| `AvgTone` | Average media tone for the event (-100 to +100) |
| `GoldsteinScale` | Theoretical stability impact (-10 to +10) |
| `QuadClass` | Primary classification: Verbal/Material × Cooperation/Conflict |
| `ActionGeo_CountryCode` | Where the event took place (FIPS10-4 2-char code) |
| `EventRootCode` | Root CAMEO event category (2-digit) |
| `NumMentions` | Total media mentions (proxy for importance) |

---

## Project Structure

```
gdelt-pipeline/
├── terraform/                  # GCP infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── schemas/
│       └── gdelt_events.json   # BigQuery table schema (58 columns)
├── pipeline/                   # Ingestion script
│   ├── ingest_gdelt.py
│   ├── requirements.txt
│   └── .env.example
├── orchestration/              # Kestra flow
│   └── flows/
│       └── gdelt_daily_pipeline.yml
├── dbt/                        # Transformations
│   ├── dbt_project.yml
│   ├── profiles.yml
│   ├── packages.yml
│   ├── models/
│   │   ├── staging/
│   │   │   ├── sources.yml
│   │   │   ├── stg_gdelt_events.sql
│   │   │   └── stg_gdelt_events.yml
│   │   └── mart/
│   │       ├── mart_daily_event_tone.sql
│   │       ├── mart_country_activity.sql
│   │       └── mart_models.yml
│   └── tests/
│       └── assert_avg_tone_in_range.sql
└── README.md
```

---

## Reproducing This Project

### Prerequisites

- GCP account with billing enabled
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.3
- [dbt-bigquery](https://docs.getdbt.com/docs/core/pip-install) (`pip install dbt-bigquery`)
- Python 3.10+
- [Docker](https://docs.docker.com/engine/install/) & Docker Compose (for local orchestration)

---

### Step 1 — Clone the repo

```bash
git clone https://github.com/Rajput2000/GDELT-ANALYSIS.git
cd GDELT-ANALYSIS
```

---

### Step 2 — Provision GCP infrastructure with Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set your GCP project_id
nano terraform.tfvars

terraform init
terraform plan
terraform apply
```

This creates:
- GCS bucket: `<project-id>-gdelt-lake`
- BigQuery datasets: `gdelt_raw`, `gdelt_staging`, `gdelt_mart`
- Service account: `gdelt-pipeline-sa` with least-privilege IAM roles
- Service account key: saved to `keys/gdelt-pipeline-sa.json`

---

### Step 3 — Run a backfill (last 30 days)

```bash
cd pipeline
pip install -r requirements.txt

cp .env.example .env
# Edit .env with your project and bucket values
source .env

python ingest_gdelt.py --days 30
```

---

### Step 4 — Set up dbt

```bash
cd dbt
export DBT_GCP_PROJECT="<your-project-id>"
export GOOGLE_APPLICATION_CREDENTIALS="../keys/gdelt-pipeline-sa.json"

dbt deps
dbt run --select tag:gdelt
dbt test --select tag:gdelt
```

---

### Step 5 — Set up Local Orchestration with Kestra

1. Navigate to the orchestration directory:
   ```bash
   cd orchestration
   ```
2. Create your `.env` file from the service account key (this feeds Kestra secrets):
   ```bash
   echo "SECRET_GCP_SA_KEY=$(cat ../keys/gdelt-pipeline-sa.json | base64)" > .env
   # Or directly set it if you prefer plain text interpolation depends on Kestra version config.
   # Standard approach provided in `docker-compose.yml`:
   export SECRET_GCP_SA_KEY=$(cat ../keys/gdelt-pipeline-sa.json)
   ```
3. Start the Kestra server:
   ```bash
   docker compose up -d
   ```
   *Note: On startup, Kestra will automatically connect via API and import the flow from `flows/gdelt_daily_pipeline.yml`.*

4. Access the UI to monitor the daily runs (or trigger one manually):
   - **URL**: [http://localhost:8080](http://localhost:8080)
   - **Username**: `admin@kestra.io`
   - **Password**: `Kestra2024`

The pipeline will now run automatically every day at 7AM UTC as long as the Docker container is running.

---

### Step 6 — Connect Looker Studio

1. Go to [lookerstudio.google.com](https://lookerstudio.google.com)
2. Create a new report → Add data → BigQuery
3. Connect to `gdelt_mart.mart_daily_event_tone` for the temporal tile
4. Connect to `gdelt_mart.mart_country_activity` for the categorical tile

---

## Data Warehouse Design

### Partitioning & Clustering

**`gdelt_raw.events`**
- Partitioned by **ingestion time** (`_PARTITIONTIME`) — each daily load lands in its own partition
- Clustered by `ActionGeo_CountryCode`, `EventRootCode`, `QuadClass`
- Rationale: dashboard queries always filter by date range and country, eliminating full table scans

**`gdelt_mart.mart_daily_event_tone`**
- Partitioned by `event_date` (DATE, daily)
- Clustered by `quad_class_label`
- Rationale: Looker Studio tile filters on the last 30 days and groups by quad class

**`gdelt_mart.mart_country_activity`**
- Clustered by `action_geo_country_code`
- Rationale: country lookups are the primary access pattern for the categorical tile

### dbt Layers

| Layer | Materialisation | Dataset | Purpose |
|---|---|---|---|
| Staging | View | `gdelt_staging` | Cast types, rename columns, filter nulls |
| Mart | Table | `gdelt_mart` | Aggregated, dashboard-ready |


