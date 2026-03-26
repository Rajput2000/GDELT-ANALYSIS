# GDELT Pipeline Infrastructure Setup

This document provides step-by-step instructions to reproduce the Google Cloud Platform infrastructure for the GDELT data pipeline.

## Prerequisites

### Required Tools
- [Terraform](https://www.terraform.io/downloads) >= 1.3
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- Git

### Google Cloud Setup
1. Create a Google Cloud Project
2. Enable required APIs:
   ```bash
   gcloud services enable storage.googleapis.com
   gcloud services enable bigquery.googleapis.com
   gcloud services enable iam.googleapis.com
   ```
3. Set up authentication:
   ```bash
   gcloud auth application-default login
   ```

## Infrastructure Components

The Terraform configuration creates:

### Storage Layer
- **GCS Bucket**: `{project_id}-gdelt-lake`
  - Lifecycle rules: Nearline after 30 days, delete after 90 days
  - Folder structure: `raw/` and `processed/`

### Data Warehouse
- **BigQuery Datasets**:
  - `gdelt_raw`: Landing zone for raw GDELT data
  - `gdelt_staging`: dbt staging models
  - `gdelt_mart`: dbt mart models for dashboards

### BigQuery Table
- **Table**: `gdelt_raw.events`
  - Partitioned by ingestion time (`_PARTITIONTIME`)
  - Clustered by: `ActionGeo_CountryCode`, `EventRootCode`, `QuadClass`
  - Schema: 57 fields covering GDELT 1.0 event structure

### Security
- **Service Account**: `gdelt-pipeline-sa`
- **IAM Roles**:
  - `roles/storage.objectAdmin`
  - `roles/bigquery.dataEditor`
  - `roles/bigquery.jobUser`
  - `roles/bigquery.metadataViewer`

## Deployment Steps

### 1. Clone Repository
```bash
git clone https://github.com/Rajput2000/GDELT-ANALYSIS.git
cd GDELT-ANALYSIS
```

### 2. Configure Variables
Copy and edit the Terraform variables:
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:
```hcl
project_id   = "your-gcp-project-id"
region       = "us-central1"
bq_location  = "US"
environment  = "dev"
```

### 3. Initialize Terraform
```bash
terraform init
```

### 4. Review Plan
```bash
terraform plan
```

### 5. Deploy Infrastructure
```bash
terraform apply
```

Type `yes` when prompted to confirm deployment.

## File Structure

```
terraform/
├── main.tf                    # Main infrastructure configuration
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output values
├── terraform.tfvars           # Variable values (not in git)
├── terraform.tfvars.example   # Example variable values
└── schemas/
    └── gdelt_events.json      # BigQuery table schema
```

## Key Outputs

After successful deployment, you'll have:

- **GCS Bucket URL**: `gs://{project_id}-gdelt-lake`
- **Service Account**: `gdelt-pipeline-sa@{project_id}.iam.gserviceaccount.com`
- **Service Account Key**: `../keys/gdelt-pipeline-sa.json`
- **BigQuery Datasets**: `gdelt_raw`, `gdelt_staging`, `gdelt_mart`

## Troubleshooting

### Common Issues

1. **Schema file not found**
   ```
   Error: Invalid function argument - no file exists at "./schemas/gdelt_events.json"
   ```
   **Solution**: Ensure `schemas/gdelt_events.json` exists in the terraform directory.

2. **Storage bucket object content missing**
   ```
   Error: either "content" or "source" must be specified
   ```
   **Solution**: Verify the bucket object resources have `content = " "` specified.

3. **BigQuery partitioning field type error**
   ```
   Error: The field specified for time partitioning can only be of type TIMESTAMP, DATE or DATETIME
   ```
   **Solution**: Use ingestion-time partitioning instead of field-based partitioning for INTEGER date fields.

### Verification Commands

Check deployed resources:
```bash
# List GCS buckets
gsutil ls

# List BigQuery datasets
bq ls

# Check service account
gcloud iam service-accounts list --filter="email:gdelt-pipeline-sa@*"
```

## Cleanup

To destroy all infrastructure:
```bash
terraform destroy
```

**Warning**: This will permanently delete all data and resources.

## Security Considerations

### Production Recommendations
1. **Use Workload Identity** instead of service account keys
2. **Enable VPC Service Controls** for data protection
3. **Implement least-privilege IAM** policies
4. **Enable audit logging** for compliance
5. **Use Cloud KMS** for encryption key management

### Service Account Key Management
- The service account key is stored locally in `../keys/gdelt-pipeline-sa.json`
- This file is excluded from git via `.gitignore`
- In production, use Workload Identity Federation instead

## Next Steps

After infrastructure deployment:

1. **Data Ingestion**: Set up scripts to load GDELT data into GCS
2. **dbt Setup**: Configure dbt for data transformations
3. **Dashboard**: Connect visualization tools to the mart dataset
4. **Monitoring**: Set up alerts and monitoring for the pipeline

## Version Information

- **Terraform Version**: >= 1.3
- **Google Provider Version**: ~> 5.0
- **BigQuery Schema Version**: GDELT 1.0 format
- **Last Updated**: $(date +%Y-%m-%d)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Terraform and Google Cloud documentation
3. Verify all prerequisites are met
4. Ensure proper GCP permissions are configured