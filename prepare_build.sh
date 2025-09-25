#!/bin/bash

LOG_FILE="$(pwd)/prepare_build.log"
>"$LOG_FILE" # Clear log file
exec > >(tee -a "$LOG_FILE") 2>&1

# =====================================
# Script to prepare OpenWrt build environment
# Usage: ./prepare_build.sh [commit_hash]
# =====================================

# Set proxy (modify if needed)
PROXY="http://127.0.0.1:1080"
HTTP_PROXY=$PROXY
HTTPS_PROXY=$PROXY
FTP_PROXY=$PROXY

# Export proxy
export http_proxy=$HTTP_PROXY
export https_proxy=$HTTPS_PROXY
export ftp_proxy=$FTP_PROXY

# Set Git repository
LEDE_REPO="https://github.com/coolsnowwolf/lede.git"

# Working directory
WORK_DIR=$(pwd)
LEDE_DIR="${WORK_DIR}/lede"

# Set additional environment variables for scripts
export GITHUB_WORKSPACE="$WORK_DIR"
export SCRIPTS_PATH="scripts"
export PLUGINS_FILE="plugins.yaml"
export RELEASE_NOTES="release.md"

# Determine commit hash from the input argument
if [ -n "$1" ]; then
  COMMIT_HASH=$1
  echo "Using provided commit hash: $COMMIT_HASH"
else
  COMMIT_HASH=""
  echo "No commit hash provided, cloning the latest code."
fi

# Clear old lede directory if exists
if [ -d "$LEDE_DIR" ]; then
  echo "Removing existing 'lede' directory..."
  rm -rf "$LEDE_DIR"
fi

# Clone lede repository
echo "Cloning lede repository..."
if ! git clone "$LEDE_REPO" "$LEDE_DIR"; then
  echo "Error: Failed to clone repository."
  exit 1
fi

# Navigate to lede directory
cd "$LEDE_DIR" || exit 1

# Reset to specific commit hash if provided
if [ -n "$COMMIT_HASH" ]; then
  echo "Resetting to commit: $COMMIT_HASH..."
  if ! git reset --hard "$COMMIT_HASH"; then
    echo "Error: Failed to reset to the specified commit."
    exit 1
  fi
else
  echo "No commit hash specified, skipping reset."
fi

# Copy additional files (feeds configuration and customization script)
echo "Copying feeds configuration and diy-part2.sh..."
cp "${WORK_DIR}/feeds.conf.default" .
cp "${WORK_DIR}/scripts/diy-part2.sh" .

# Update and install feeds
echo "Updating and installing feeds..."
if ! ./scripts/feeds update -a || ! ./scripts/feeds install -a; then
  echo "Error: Failed to update or install feeds."
  exit 1
fi

# Run diy-part2.sh for customization
if [ -f "${WORK_DIR}/scripts/diy-part2.sh" ]; then
  echo "Running diy-part2.sh script..."
  bash diy-part2.sh
else
  echo "Warning: diy-part2.sh not found, skipping customization."
fi

echo "OpenWrt build environment is ready."
