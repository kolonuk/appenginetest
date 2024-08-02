#!/bin/bash

# Variables
PROJECT_NAME="my-simple-php-app"
PROJECT_ID="my-simple-php-app-$(date +%s)"
SERVICE_ACCOUNT_NAME="github-actions"
REGION="us-central1"
REPO="your-username/your-repo"

# Authenticate with Google Cloud SDK
gcloud auth login

# Create a new project
gcloud projects create $PROJECT_ID --name=$PROJECT_NAME

# Set the project
gcloud config set project $PROJECT_ID

# Enable required services
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# Create a service account
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME --display-name="GitHub Actions"

# Assign roles to the service account
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/run.admin"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudbuild.builds.editor"

# Create and download service account key
gcloud iam service-accounts keys create key.json \
  --iam-account=${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com

# Install GitHub CLI if not already installed
if ! command -v gh &> /dev/null
then
    echo "gh could not be found, installing..."
    sudo apt-get install gh
fi

# Authenticate with GitHub CLI
gh auth login

# Add GitHub secrets
gh secret set GCP_SA_KEY -b"$(cat key.json)" -R $REPO
gh secret set GCP_PROJECT_ID -b"$PROJECT_ID" -R $REPO
gh secret set GCP_REGION -b"$REGION" -R $REPO

echo "Project setup complete. GitHub secrets have been set up for repository $REPO."
