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
│                        Kestra Cloud                             │
│                  (daily schedule — 7AM UTC)                     │
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
                    │  (2 tiles, live BQ)    │
                    └────────────────────────┘
```

---

## Technologies

| Layer | Tool | Purpose |
|---|---|---|
| Infrastructure as Code | [Terraform](https://www.terraform.io/) | Provision GCS bucket, BigQuery datasets, service account + IAM |
| Cloud | [GCP](https://cloud.google.com/) | GCS (data lake), BigQuery (data warehouse) |
| Orchestration | [Kestra Cloud](https://kestra.io/) | Daily scheduled pipeline — download → GCS → BigQuery → dbt |
| Data Lake | [Google Cloud Storage](https://cloud.google.com/storage) | Raw GDELT CSV files, date-partitioned |
| Data Warehouse | [BigQuery](https://cloud.google.com/bigquery) | Ingestion-time partitioned, clustered by country + event type |
| Transformations | [dbt](https://www.getdbt.com/) | Staging views + mart tables with tests |
| Dashboard | [Looker Studio](https://lookerstudio.google.com/) | Two-tile live dashboard connected to BigQuery mart |

---

## Dashboard

The dashboard answers two questions visually:

**Tile 1 — Global Event Tone Over Time** *(temporal)*
Daily average media tone and event volume over the last 30 days, broken down by quad class (Verbal Cooperation, Material Cooperation, Verbal Conflict, Material Conflict). Reveals whether global news is trending more positive or negative.

**Tile 2 — Top Countries by Event Activity** *(categorical)*
Bar chart of the most active countries in global news over the last 30 days, coloured by average tone. Reveals which countries are dominating coverage and whether that coverage is positive or negative.

> 🔗 **[View the live dashboard](#)** ← replace with your Looker Studio link

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
- [Kestra Cloud](https://app.kestra.io) free account

---

### Step 1 — Clone the repo

```bash
git clone https://github.com/<your-username>/gdelt-pipeline.git
cd gdelt-pipeline
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

### Step 5 — Set up Kestra Cloud (daily automation)

1. Sign up at [app.kestra.io](https://app.kestra.io) and create namespace `gdelt`
2. Add namespace **Variables** (Namespaces → gdelt → Variables):
   ```yaml
   gcp_project: "<your-project-id>"
   gcs_bucket:  "<your-project-id>-gdelt-lake"
   environment: "prod"
   ```
3. Add namespace **Secret** (Namespaces → gdelt → Secrets):
   - Key: `GCP_SA_KEY`
   - Value: contents of `keys/gdelt-pipeline-sa.json`
4. Import the flow: Flows → Import → select `orchestration/flows/gdelt_daily_pipeline.yml`

The pipeline will now run automatically every day at 7AM UTC.

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

---

## Evaluation Criteria Checklist

| Criterion | Implementation | Points |
|---|---|---|
| Problem description | Described above — clear problem, clear solution | 4 |
| Cloud | GCP (GCS + BigQuery) + Terraform IaC | 4 |
| Data ingestion (batch) | End-to-end Kestra DAG: download → GCS → BigQuery | 4 |
| Data warehouse | BigQuery, partitioned + clustered with explanation | 4 |
| Transformations | dbt staging + mart models with tests | 4 |
| Dashboard | Looker Studio, 2 tiles (temporal + categorical) | 4 |
| Reproducibility | Step-by-step instructions above | 4 |
