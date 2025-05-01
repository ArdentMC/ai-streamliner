#!/bin/bash

# --- Configuration ---
# The exact string to search for within the YAML file.
# Note: These are literal strings 'AWS_REGION' and 'CLUSTER_ID', not variables here.

# Set error handling
set -e

# Check if exactly two arguments are provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <NewClusterID>"
  echo "  Example: $0 EKS_OIDC_ID_SUFFIX"
  exit 1
fi

SEARCH_STRING="https://oidc.eks.AWS_REGION.amazonaws.com/id/CLUSTER_ID"
YAML_FILE="manifests/common/oauth2-proxy/overlays/m2m-dex-and-eks/kustomization.yaml"
MANIFESTS_DIR="manifests"

# --- Argument Handling ---

# Assign arguments to variables for clarity
NEW_CLUSTER_ID="$1"

# Check if manifests directory already exists
if [ -d "$MANIFESTS_DIR" ]; then
  echo "Manifests directory already exists at '${MANIFESTS_DIR}'"
  
  # Ask user what to do
  read -p "Do you want to (u)se existing, (r)emove and clone fresh, or (a)bort? [u/r/a]: " choice
  
  case "$choice" in
    u|U)
      echo "Using existing manifests directory..."
      ;;
    r|R)
      echo "Removing existing and cloning fresh manifests..."
      rm -rf "$MANIFESTS_DIR"
      git clone https://github.com/kubeflow/manifests.git
      git checkout b5f07cda3218e42b2762c73723d29eb7904ed3fe #commit @ time of writing ** untested**
      ;;
    *)
      echo "Aborting operation."
      exit 0
      ;;
  esac
else
  echo "Cloning manifests repository..."
  git clone https://github.com/kubeflow/manifests.git
  git checkout b5f07cda3218e42b2762c73723d29eb7904ed3fe #commit @ time of writing **untested**
fi

# Check if the target YAML file exists
if [ ! -f "$YAML_FILE" ]; then
  echo "Error: YAML file not found at '$YAML_FILE'"
  exit 1
fi

# --- Main Logic ---

echo "Searching for:"
echo "  '$SEARCH_STRING'"
echo "Replacing with:"
echo "  '$NEW_CLUSTER_ID'"
echo "In file:"
echo "  '$YAML_FILE'"
echo "---"

# Use sed to perform the replacement in-place.
# -i flag modifies the file directly.
# We use '#' as the delimiter for the 's' command because the SEARCH_STRING contains '/'.
# Double quotes around the sed command allow shell variable expansion for $NEW_CLUSTER_ID.
# The 'g' flag ensures all occurrences on a line are replaced (though likely only one here).

# Note on portability: The '-i' flag behaves slightly differently on macOS/BSD vs Linux.
# On Linux (GNU sed), '-i' works as is.
# On macOS/BSD sed, you might need '-i ""' (sed -i "" "s#...#...#g" "$YAML_FILE")
# to perform in-place editing without creating a backup file.
# Try Linux version of sed first
if sed -i "s#${SEARCH_STRING}#${NEW_CLUSTER_ID}#g" "$YAML_FILE" 2>/dev/null; then
  echo "Replacement completed successfully using Linux sed."
else
  # If Linux version fails, try macOS version without exiting
  echo "Linux sed command failed. Trying macOS version..."
  if sed -i '' "s#${SEARCH_STRING}#${NEW_CLUSTER_ID}#g" "$YAML_FILE" 2>/dev/null; then
    echo "Replacement completed successfully using macOS sed."
  else
    echo "Warning: Both sed variants failed. The replacement may not have been applied."
    exit 1
  fi
fi

echo "Updating kustomization.yaml to use m2m-dex-and-eks overlay..."

# --- Update kustomization.yaml ---
# Path to the kustomization.yaml file
KUSTOMIZATION_YAML="manifests/example/kustomization.yaml"
# Line to comment out
DEX_ONLY_LINE="- ../common/oauth2-proxy/overlays/m2m-dex-only     # for all clusters"

# Try Linux version of sed first for commenting
if sed -i "s|${DEX_ONLY_LINE}|# ${DEX_ONLY_LINE}|g" "$KUSTOMIZATION_YAML" 2>/dev/null; then
  echo "Successfully commented out dex-only line using Linux sed."
else
  # If Linux version fails, try macOS version
  echo "Linux sed command failed. Trying macOS version..."
  if sed -i '' "s|${DEX_ONLY_LINE}|# ${DEX_ONLY_LINE}|g" "$KUSTOMIZATION_YAML" 2>/dev/null; then
    echo "Successfully commented out dex-only line using macOS sed."
  else
    echo "Warning: Failed to comment out dex-only line."
    exit 1
  fi
fi

# --- Uncomment the dex-and-eks line ---
# Line to uncomment
DEX_AND_EKS_LINE="#- ../common/oauth2-proxy/overlays/m2m-dex-and-eks  # for EKS clusters (NOTE: requires you to configure issuer, see overlay)"
UNCOMMENTED_LINE="- ../common/oauth2-proxy/overlays/m2m-dex-and-eks  # for EKS clusters (NOTE: requires you to configure issuer, see overlay)"

# Try Linux version of sed first for uncommenting
if sed -i "s|${DEX_AND_EKS_LINE}|${UNCOMMENTED_LINE}|g" "$KUSTOMIZATION_YAML" 2>/dev/null; then
  echo "Successfully uncommented dex-and-eks line using Linux sed."
else
  # If Linux version fails, try macOS version
  echo "Linux sed command failed. Trying macOS version..."
  if sed -i '' "s|${DEX_AND_EKS_LINE}|${UNCOMMENTED_LINE}|g" "$KUSTOMIZATION_YAML" 2>/dev/null; then
    echo "Successfully uncommented dex-and-eks line using macOS sed."
  else
    echo "Warning: Failed to uncomment dex-and-eks line."
    exit 1
  fi
fi

# --- Final Steps ---
echo "Deploying Kubeflow..."

# Function to apply resources with retries
apply_resources() {
  echo "Applying resources with kustomize..."
  
  # Retry logic with timeout
  local max_attempts=5
  local attempt=1
  local timeout=20
  
  cd manifests && \
  while ! kustomize build example | kubectl apply --server-side --force-conflicts -f -; do
    echo "Attempt $attempt failed. Retrying to apply resources in $timeout seconds..."
    
    if [ $attempt -ge $max_attempts ]; then
      echo "Failed after $max_attempts attempts. Exiting."
      return 1
    fi
    
    sleep $timeout
    ((attempt++))
  done
  
  echo "Resources applied successfully."
  return 0
}

# Execute the function
apply_resources

# Exit with the function's return code
exit $?