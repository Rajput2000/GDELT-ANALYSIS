# dbt Transformations

This directory contains the dbt project for transforming GDELT data within BigQuery. The data pipeline is designed with a two-layer architecture:
1. **Staging (`gdelt_staging`)**: Raw data normalized into views (e.g., `stg_gdelt_events`).
2. **Mart (`gdelt_mart`)**: Final transformed tables modeled for downstream dashboarding.
   - `mart_daily_event_tone`: Provides daily temporal aggregations of event tone and frequency.
   - `mart_country_activity`: Provides categorical aggregations around top countries and their tones over the last 30 days.

## Prerequisites

Before running the dbt models, ensure you have the following environment variables set:
- `DBT_GCP_PROJECT`: Your Google Cloud Project ID.
- `GOOGLE_APPLICATION_CREDENTIALS`: Path to your Google Cloud service account key file.

This project connects to BigQuery using the provided `profiles.yml` file, which includes two targets:
- `dev`: Uses local oauth (`gcloud auth application-default login` credentials).
- `prod`: Uses the service account key defined in `GOOGLE_APPLICATION_CREDENTIALS`.

## How to Run

1. **Install Dependencies**
   ```bash
   dbt deps
   ```

2. **Run Models**
   Run all staging and mart models using the configuration in the current directory:
   ```bash
   dbt run --profiles-dir .
   ```
   To run specifically against the `prod` target:
   ```bash
   dbt run --target prod --profiles-dir .
   ```

3. **Test Models**
   Run the tests defined in the `tests` directory and in model properties:
   ```bash
   dbt test --profiles-dir .
   ```
