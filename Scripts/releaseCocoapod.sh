#!/bin/bash

# Variables
REPO="ParticleMedia/msp-ios-sdk-public"           # Replace with your GitHub repo (e.g., "username/my-app")
TAG="0.0.104"                          # Replace with the version tag you want to use
SOURCE_DIRS=("MSPSharedLibraries")  # Array of source directories to be compressed
ZIP_NAME="MSPSharedLibraries-${TAG}.zip"      # Name of the zip file for the release assets
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
