#!/bin/bash

# Variables
PROJECT_NAME="cloudruntest"
PROJECT_ID="cloudruntest-$(date +%s)"
SERVICE_ACCOUNT_NAME="github"
REGION="europe-west1"
WIP_NAME="github"
GITHUB_ORG="kolonuk"
REPO="cloudruntest"

# Authenticate with Google Cloud SDK
#gcloud auth login  # enable only required for first run

# Authenticate with GitHub CLI
#gh auth login # enable only required for first run

# Create a new project
gcloud projects create $PROJECT_ID --name=$PROJECT_NAME > /dev/null

# Set the project
gcloud config set project $PROJECT_ID

# Set billing account
BILLING_ACCOUNT=$(gcloud beta billing accounts list --format="value(ACCOUNT_ID)" --filter="OPEN=True" | head -n 1)
gcloud beta billing projects link ${PROJECT_ID} --billing-account=${BILLING_ACCOUNT} > /dev/null

# Enable required services
echo y|gcloud services enable run.googleapis.com
echo y|gcloud services enable cloudbuild.googleapis.com
echo y|gcloud services enable iamcredentials.googleapis.com

# Create a service account
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME --display-name="GitHub Actions" > /dev/null

# Assign roles to the service account
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/run.admin" > /dev/null
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser" > /dev/null
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudbuild.builds.editor" > /dev/null
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.admin" > /dev/null
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/viewer" > /dev/null
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator" > /dev/null

# Assign the Workload Identity Pool Admin role to the current user
GCLOUD_USER=$(gcloud config get account)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:${GCLOUD_USER}" \
  --role="roles/iam.workloadIdentityPoolAdmin" > /dev/null

# Do WIF authentication
gcloud iam workload-identity-pools create "${WIP_NAME}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool" > /dev/null

WIPOOL=$(gcloud iam workload-identity-pools describe "${WIP_NAME}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --format="value(name)")

gcloud iam workload-identity-pools providers create-oidc "my-repo" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${WIP_NAME}" \
  --display-name="My GitHub repo Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == '${GITHUB_ORG}'" \
  --issuer-uri="https://token.actions.githubusercontent.com" > /dev/null

WIPROVIDER=$(gcloud iam workload-identity-pools providers describe "my-repo" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${WIP_NAME}" \
  --format="value(name)")

# Allow the service account to impersonate
gcloud iam service-accounts add-iam-policy-binding ${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${WIPOOL}/attribute.repository/${REPO}" > /dev/null

# Add GitHub secrets
gh variable set GCP_PROJECT_ID -b"$PROJECT_ID" -R $GITHUB_ORG/$REPO
gh variable set GCP_REGION -b"$REGION" -R $GITHUB_ORG/$REPO
gh variable set GCP_SERVICE_ACCOUNT -b"${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" -R $GITHUB_ORG/$REPO
gh variable set GCP_WORKLOAD_IDENTITY_PROVIDER -b"$WIPROVIDER" -R $GITHUB_ORG/$REPO

echo "Project setup complete. GitHub secrets have been set up for repository $GITHUB_ORG/$REPO."
