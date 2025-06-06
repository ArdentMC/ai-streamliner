#!/bin/bash
set -e

# 1. Setup: variables
LAKEFS_API="http://localhost:8082/api/v1"
LAKEFS_CREDS="-u access:secret"
LAKEFS_REPO="simple-repo"
LAKEFS_BRANCH="main"
STORAGE_NS="local://simple-repo-data"
DATA_FILE="myfile.txt"
COMMIT_MSG="Upload myfile.txt"

# 2. Setup variables for MLflow
MLFLOW_TRACKING_URI="http://localhost:8083"
MLFLOW_EXPERIMENT_NAME="lakefs_integration_demo"
MLFLOW_RUN_NAME="lakefs_run_1"

# 3. Create a trivial file
echo "hello from lakefs and mlflow!" > $DATA_FILE

# 4. Create LakeFS repo if needed
REPO_EXISTS=$(curl -s $LAKEFS_CREDS "$LAKEFS_API/repositories/$LAKEFS_REPO" | jq -r '.id // empty')
if [ -z "$REPO_EXISTS" ]; then
    curl -s $LAKEFS_CREDS -X POST "$LAKEFS_API/repositories" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$LAKEFS_REPO\", \"storage_namespace\": \"$STORAGE_NS\", \"default_branch\": \"$LAKEFS_BRANCH\"}"
else
    echo "Repository $LAKEFS_REPO already exists"
fi

# 5. Upload the file to LakeFS
curl -s $LAKEFS_CREDS -X POST "$LAKEFS_API/repositories/$LAKEFS_REPO/branches/$LAKEFS_BRANCH/objects?path=$DATA_FILE" \
  -H "Content-Type: application/json" \
  -d @<(jq -Rs --arg path "$DATA_FILE" '{ path: $path, content: . }' < $DATA_FILE)

# 6. Commit in LakeFS
curl -s $LAKEFS_CREDS -X POST "$LAKEFS_API/repositories/$LAKEFS_REPO/branches/$LAKEFS_BRANCH/commits" \
  -H "Content-Type: application/json" \
  -d "{\"message\": \"$COMMIT_MSG\"}"

# 7. List files in LakeFS
curl -s $LAKEFS_CREDS \
  "$LAKEFS_API/repositories/$LAKEFS_REPO/refs/$LAKEFS_BRANCH/objects/ls?prefix=" | jq

echo "LakeFS UI: http://localhost:8082/repositories/$LAKEFS_REPO/objects?ref=$LAKEFS_BRANCH"

# 8. (NEW) Log an MLflow experiment and artifact
export MLFLOW_TRACKING_URI=$MLFLOW_TRACKING_URI
cd mlflow/sample_project

# Create experiment if it doesn't exist
mlflow experiments search | grep -q "$MLFLOW_EXPERIMENT_NAME" || mlflow experiments create -n "$MLFLOW_EXPERIMENT_NAME"

# Create the file
echo "hello from lakefs and mlflow!" > myfile.txt

LAKEFS_COMMIT_ID=$(curl -s $LAKEFS_CREDS "$LAKEFS_API/repositories/$LAKEFS_REPO/branches/$LAKEFS_BRANCH" | jq -r .commit_id)
LAKEFS_COMMIT_URL="http://localhost:8082/repositories/$LAKEFS_REPO/commits/$LAKEFS_COMMIT_ID"

mlflow run . \
  -P data_file=myfile.txt \
  -P lakefs_commit=$LAKEFS_COMMIT_ID \
  -P lakefs_commit_url=$LAKEFS_COMMIT_URL \
  --experiment-name "lakefs_integration_demo" \
  --run-name "lakefs_run_1" \
  --env-manager=local
