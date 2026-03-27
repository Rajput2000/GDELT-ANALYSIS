# Pipeline Orchestration

This directory handles the pipeline orchestration using [Kestra](https://kestra.io/) and PostgreSQL for metadata storage, all encapsulated in a local Docker Compose setup.

## Setup

1. **Environment Variables**: Make sure the `.env` file exists in this directory. Based on the configuration, it should contain the `SECRET_GCP_SA_KEY` environment variable.
2. **Key File**: The Docker Compose setup maps a local service account key file to the container for Google Cloud authentication. Make sure your service account JSON file is placed at `../keys/gdelt-pipeline-sa.json` (relative to this directory).

## How to Run Locally

1. **Start the Orchestration Services**
   ```bash
   docker compose up -d
   ```
   This command starts the local Kestra instance and its PostgreSQL database. During startup, Kestra will automatically connect via the API and import all `.yml` flows from the `flows` directory.

2. **Access the Kestra UI**  
   Once the health checks pass, open your browser and navigate to the Kestra UI:
   [http://localhost:8080](http://localhost:8080)
   - **Username**: `admin@kestra.io`
   - **Password**: `Kestra2024`

3. **Monitor Container Logs**
   Check what Kestra is doing on execution:
   ```bash
   docker compose logs -f kestra
   ```

4. **Stop Services**
   Tear down all orchestrated containers:
   ```bash
   docker compose down
   ```
