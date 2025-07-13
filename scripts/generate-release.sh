#!/usr/bin/env bash
#
# This script generates the release.md file by extracting versions
# from Makefiles defined in plugins.yaml and other system info.
# It must be run in the root of the OpenWrt source tree.
#
set -euo pipefail

RELEASE_NOTES_FILE="$GITHUB_WORKSPACE/$RELEASE_NOTES"
PLUGINS_FILE="$GITHUB_WORKSPACE/$PLUGINS_FILE"

# 1. Extract Kernel Version
# Ensure we are in the correct directory for this
if [ ! -f "include/kernel-6.6" ]; then
  echo "Error: Kernel config not found. This script must be run from the OpenWrt source root." >&2
  exit 1
fi
MAJOR="6.6"
RAW_PATCH=$(grep -E '^LINUX_VERSION-6\.6' include/kernel-6.6 | awk -F'= ' '{print $2}')
PATCH="${RAW_PATCH#.}"
KERNEL_VERSION="${MAJOR}.${PATCH}"
echo "[INFO] Kernel Version: ${KERNEL_VERSION}"

# 2. Generate Plugin Table
# Capture the entire output of the while loop into the TABLE variable.
# This is a more robust way to handle multi-line strings.
TABLE=$(while IFS= read -r plugin_json; do
  name=$(echo "$plugin_json" | jq -r '.name')
  desc=$(echo "$plugin_json" | jq -r '.desc')
  version_str=""

  # Check if a static version is defined
  if echo "$plugin_json" | jq -e 'has("version")' >/dev/null; then
    version=$(echo "$plugin_json" | jq -r '.version')
    version_str="_${version}_"
  # Check if a path for version extraction is defined
  elif echo "$plugin_json" | jq -e 'has("path")' >/dev/null; then
    path=$(echo "$plugin_json" | jq -r '.path')
    if [ -f "$path" ]; then
      # Extract version, handling potential whitespace
      version=$(grep -Po 'PKG_VERSION:=\s*\K.*' "$path")
      if [ -n "$version" ]; then
        version_str="**${version}**"
      else
        version_str="_n/a_"
        echo "[WARNING] Could not extract version for '${name}' from '${path}'" >&2
      fi
    else
      version_str="_n/a_"
      echo "[WARNING] Makefile not found for '${name}' at '${path}'" >&2
    fi
  fi

  printf "| %s | %s | %s |\n" "$name" "$version_str" "$desc"
done < <(yq e -o=j -I=0 '.[]' "$PLUGINS_FILE"))

# Remove trailing newline from table if it exists
TABLE=$(echo -e "$TABLE" | sed '/^$/d')

echo "[INFO] Generated Plugin Table:"
echo -e "$TABLE"

# 3. Update release.md
# Create temporary files for the new content and the table
TEMP_RELEASE=$(mktemp)
TABLE_FILE=$(mktemp)
# Ensure temp files are cleaned up on exit
trap 'rm -f "$TEMP_RELEASE" "$TABLE_FILE"' EXIT

# Write the generated table to its temp file
echo -e "$TABLE" >"$TABLE_FILE"

# Use awk to replace placeholders. This is more robust for multi-line content.
awk -v kernel_version="$KERNEL_VERSION" -v table_file="$TABLE_FILE" '
  # Replace kernel version placeholder
  $0 ~ /{{KERNEL_VERSION}}/ {
    gsub("{{KERNEL_VERSION}}", kernel_version)
  }
  # Check for the plugin table placeholder
  /{{PLUGIN_TABLE}}/ {
    # Read the table content from the temp file and print it
    while ((getline line < table_file) > 0) {
      print line
    }
    close(table_file)
    next
  }
  # Print all other lines
  { print }
' "$RELEASE_NOTES_FILE" >"$TEMP_RELEASE"

# Overwrite the original file with the updated content
mv "$TEMP_RELEASE" "$RELEASE_NOTES_FILE"

echo "[INFO] Successfully generated $RELEASE_NOTES_FILE"
