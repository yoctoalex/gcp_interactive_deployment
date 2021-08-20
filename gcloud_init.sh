gcloud services enable compute.googleapis.com 
gcloud services enable dns.googleapis.com 
gcloud services enable sqladmin.googleapis.com

# set env variables
ZONE_NAME=us-central1-a
PROJECT_ID=$(gcloud info --format="value(config.project)")
SQL_INSTANCE_NAME=sqldatabase
SQL_DATABASE_NAME=postgres
SQL_ROOT_PASSWORD=example
PROJECT_UNIQUE_PREFIX=$(tr -dc a-z0-9 </dev/urandom | head -c 20 ; echo '')

# create database
gcloud sql instances create $SQL_INSTANCE_NAME \
--database-version=POSTGRES_13 \
--cpu=4 \
--memory=26GB \
--zone=$ZONE_NAME \
--root-password=$SQL_ROOT_PASSWORD \
--database-flags=cloudsql.iam_authentication=on

# restore database from backup
gsutil mb gs://$PROJECT_UNIQUE_PREFIX-sqlbackup
gsutil cp ./backup.sql.gz gs://$PROJECT_UNIQUE_PREFIX-sqlbackup
gcloud sql import sql $SQL_INSTANCE_NAME gs://$PROJECT_UNIQUE_PREFIX-sqlbackup/backup.sql.gz --database=$SQL_DATABASE_NAME

# get compute service account
IAM_COMPUTE_ACCOUNT_FULL_NAME=$(gcloud iam service-accounts list --format="value(email)" --filter=displayName:"Compute Engine default service account")
IAM_COMPUTE_ACCOUNT=$(echo "$IAM_COMPUTE_ACCOUNT_FULL_NAME" | sed "s/.gserviceaccount.com//g")

# add IAM user to sql database
gcloud sql users create $IAM_COMPUTE_ACCOUNT \
--instance=$SQL_INSTANCE_NAME \
--type=cloud_iam_service_account
