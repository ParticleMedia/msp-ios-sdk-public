#!/bin/bash

# Variables

# Allowed Pod names
ALLOWED_PODS=("MSPCore" "MSPSharedLibraries" "GoogleAdapter" "FacebookAdapter" "NovaAdapter" "PrebidAdapter" "UnityAdapter" "MintegralAdapter" "MobilefuseAdapter" "PubmaticAdapter" "InmobiAdapter")

# Function to check if a value exists in an array
is_valid_pod() {
  local pod="$1"
  for allowed_pod in "${ALLOWED_PODS[@]}"; do
    if [[ "$pod" == "$allowed_pod" ]]; then
      return 0  # Found, valid pod
    fi
  done
  return 1  # Not found, invalid pod
}

# Prompt user for the Pod name
read -p "Enter the Pod name: " POD_NAME

# Validate the Pod name
if ! is_valid_pod "$POD_NAME"; then
  echo "Error: Invalid Pod name! Choose from: ${ALLOWED_PODS[*]}"
  exit 1
fi

# Prompt user for the release version tag
read -p "Enter the release version (e.g., 0.0.104): " TAG
if [[ -z "$TAG" ]]; then
  echo "Error: You must provide a release version!"
  exit 1
fi

REPO="ParticleMedia/msp-ios-sdk-public"
#TAG="Your release version"   # Replace with the version tag you want to use
#POD_NAME = "Your pod name"   #Replace with the Pod you want to publish
SOURCE_DIRS=("${POD_NAME}")  # Array of source directories to be compressed, in our project, the directories are usually the Pod's name
ZIP_NAME="${POD_NAME}-${TAG}.zip"      # Name of the zip file for the release assets
ASSETS_DIR="output"           # Directory where assets like zip will be stored
#GITHUB_TOKEN="your_github_token"      # Optionally, set your GitHub token for authentication

# Function to check if a release exists
release_exists() {
  gh release view "$TAG" --repo "$REPO" &>/dev/null
}

# Function to create the zip of your source code or assets
compress_assets() {
  echo "Compressing assets..."
  # Create a zip file that contains all source directories
  zip -r "$ZIP_NAME" "${SOURCE_DIRS[@]}"  # Using the array to compress multiple directories
  mv "$ZIP_NAME" "$ASSETS_DIR"  # Move the zip file to the assets directory
  
  # Wait for the zip file to be created and fully written to disk
  while [ ! -f "$ASSETS_DIR/$ZIP_NAME" ]; do
    echo "Waiting for zip file to be fully created..."
    sleep 1
  done
  
  # Check the file size to ensure it’s non-zero (i.e., the zip file is not empty)
  while [ ! -s "$ASSETS_DIR/$ZIP_NAME" ]; do
    echo "Waiting for zip file to be non-empty..."
    sleep 1
  done
  
  echo "Zip file is ready for upload."
}

# Upload assets to GitHub release
upload_assets() {
  echo "Uploading assets..."
  gh release upload "$TAG" "$ASSETS_DIR/$ZIP_NAME" --repo "$REPO" --clobber
}

# Create or update release
if release_exists; then
  echo "Release $TAG already exists. Uploading new assets..."
  compress_assets  # Compress the assets before uploading
  upload_assets
else
  echo "Release $TAG does not exist. Creating release and uploading assets..."
  # Create a new release and upload the assets
  compress_assets  # Compress the assets before uploading
  gh release create "$TAG" "$ASSETS_DIR/$ZIP_NAME" --repo "$REPO"
  upload_assets
fi
