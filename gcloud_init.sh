echo "Enabling compute.googleapis.com"
gcloud services enable compute.googleapis.com 
echo "Enabling dns.googleapis.com "
gcloud services enable dns.googleapis.com 
echo "Enabling sqladmin.googleapis.com"
gcloud services enable sqladmin.googleapis.com

# set env variables
ZONE_NAME=us-central1-a
PROJECT_ID=$(gcloud info --format="value(config.project)")
SQL_INSTANCE_NAME=sqldatabase
SQL_DATABASE_NAME=postgres
SQL_ROOT_PASSWORD=example
PROJECT_UNIQUE_PREFIX=$(tr -dc a-z0-9 </dev/urandom | head -c 20 ; echo '')

echo "Creating Cloud SQL database"
# create database
gcloud sql instances create $SQL_INSTANCE_NAME \
    --no-assign-ip \
    --database-version=POSTGRES_13 \
    --cpu=4 \
    --memory=26GB \
    --zone=$ZONE_NAME \
    --root-password=$SQL_ROOT_PASSWORD \
    --database-flags=cloudsql.iam_authentication=on

echo "Adding IAM user to the SQL instance"
# get compute service account
IAM_COMPUTE_ACCOUNT_FULL_NAME=$(gcloud iam service-accounts list --format="value(email)" --filter=displayName:"Compute Engine default service account")
IAM_COMPUTE_ACCOUNT=$(echo "$IAM_COMPUTE_ACCOUNT_FULL_NAME" | sed "s/.gserviceaccount.com//g")

# add IAM user to sql database
gcloud sql users create $IAM_COMPUTE_ACCOUNT \
    --instance=$SQL_INSTANCE_NAME \
    --type=cloud_iam_service_account

echo "Restoring DB from the backup"
# restore database from backup
gsutil mb gs://$PROJECT_UNIQUE_PREFIX-sqlbackup
gsutil cp ./backup.sql.gz gs://$PROJECT_UNIQUE_PREFIX-sqlbackup
IAM_SQL_ACCOUNT_FULL_NAME=$(gcloud sql instances describe $SQL_INSTANCE_NAME --format="value(serviceAccountEmailAddress)")
gsutil acl ch -u $IAM_SQL_ACCOUNT_FULL_NAME:R gs://$PROJECT_UNIQUE_PREFIX-sqlbackup;
gsutil acl ch -u $IAM_SQL_ACCOUNT_FULL_NAME:R gs://$PROJECT_UNIQUE_PREFIX-sqlbackup/backup.sql.gz;
gcloud sql import sql $SQL_INSTANCE_NAME gs://$PROJECT_UNIQUE_PREFIX-sqlbackup/backup.sql.gz --database=$SQL_DATABASE_NAME -q
gsutil rm -r gs://$PROJECT_UNIQUE_PREFIX-sqlbackup

echo "--------------------------------------"
echo "SQL Password is: $SQL_ROOT_PASSWORD"
echo ""
echo "Execute commands to grant permissions: "
echo ""
echo "gcloud sql connect $SQL_INSTANCE_NAME --user=postgres"
echo "grant SELECT, INSERT, UPDATE, DELETE on WINELIST to \"$IAM_COMPUTE_ACCOUNT\";"

 
