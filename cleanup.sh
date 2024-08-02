#!/bin/bash

# Variables
PROJECT_ID=$1

if [ -z "$PROJECT_ID" ]; then
  echo "Usage: $0 PROJECT_ID"
  exit 1
fi

# Authenticate with Google Cloud SDK
gcloud auth login

# Delete the project
gcloud projects delete $PROJECT_ID --quiet

echo "Project $PROJECT_ID deleted."
