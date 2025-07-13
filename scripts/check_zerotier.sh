#!/bin/sh

# Logging function with timestamp
log() {
  echo "[$(date '+%F %T')] $*"
}

# -------------------------------
# Variables (Top-Level Declaration)
# -------------------------------

# Read ZeroTier UCI enabled status
ENABLED=$(uci get zerotier.sample_config.enabled 2>/dev/null)

# Read target peer ID from UCI
TARGET_PEER_ID=$(uci get zerotier.sample_config.join 2>/dev/null | cut -c1-10)

# Read orbit IDs from moons.d
MOON_FILES=$(ls /var/lib/zerotier-one/moons.d/*.moon 2>/dev/null)
ORBIT_IDS=""
if [ -n "$MOON_FILES" ]; then
  for file in $MOON_FILES; do
    basename=$(basename "$file")
    id=${basename#000000}
    id=${id%.moon}
    if [ -z "$ORBIT_IDS" ]; then
      ORBIT_IDS="$id"
    else
      ORBIT_IDS="$ORBIT_IDS $id"
    fi
  done
fi

# Parse --force flag
FORCE=false
if [ "$1" = "--force" ]; then
  FORCE=true
fi

# -------------------------------
# Script Execution Logic
# -------------------------------

# Check if ZeroTier is enabled
if [ "$ENABLED" != "1" ]; then
  log "[INFO] ZeroTier is not enabled. Skipping health check."
  exit 0
fi
log "[INFO] ZeroTier is enabled. Starting peer health check..."

# Validate target peer ID
if [ -z "$TARGET_PEER_ID" ]; then
  log "[ERROR] Failed to read TARGET_PEER_ID from UCI."
  exit 1
fi
log "[INFO] Target Peer ID: $TARGET_PEER_ID"

# Display found Moon IDs
if [ -n "$ORBIT_IDS" ]; then
  log "[INFO] Found Moon IDs: $ORBIT_IDS"
else
  log "[INFO] No .moon files found. Orbit will be skipped."
fi

# Display force mode if enabled
if [ "$FORCE" = true ]; then
  log "[INFO] Force mode enabled. Will execute recovery regardless of peer state."
fi

# Check peer status
HAS_BAD_PEER=""
if command -v zerotier-cli >/dev/null 2>&1 && [ -n "$TARGET_PEER_ID" ]; then
  HAS_BAD_PEER=$(zerotier-cli listpeers | awk -v peer="$TARGET_PEER_ID" '$3 == peer && $5 == "-1" && $7 == "LEAF"')
fi

if [ -n "$HAS_BAD_PEER" ] || [ "$FORCE" = true ]; then
  if [ -n "$HAS_BAD_PEER" ]; then
    log "[INFO] Found bad peer: $TARGET_PEER_ID"
  else
    log "[INFO] No bad peer found, but proceeding due to --force flag."
  fi

  # Stop ZeroTier
  log "[INFO] Stopping ZeroTier..."
  /etc/init.d/zerotier stop
  if [ $? -ne 0 ]; then
    log "[ERROR] Failed to stop ZeroTier."
    exit 1
  fi
  log "[INFO] ZeroTier stopped."

  # Remove ZeroTier config
  log "[INFO] Removing ZeroTier config..."
  rm -rf /etc/config/zero/
  if [ $? -ne 0 ]; then
    log "[ERROR] Failed to remove config."
    exit 1
  fi
  log "[INFO] Config removed."

  # Start ZeroTier
  log "[INFO] Starting ZeroTier..."
  /etc/init.d/zerotier start
  if [ $? -ne 0 ]; then
    log "[ERROR] Failed to start ZeroTier."
    exit 1
  fi
  log "[INFO] ZeroTier started."

  # Wait for zerotier-one daemon to be ready
  log "[INFO] Waiting for zerotier-one to be ready..."
  for i in $(seq 1 10); do
    if [ -f /var/lib/zerotier-one/zerotier-one.port ]; then
      log "[INFO] zerotier-one is ready."
      break
    fi
    sleep 1
  done

  if [ ! -f /var/lib/zerotier-one/zerotier-one.port ]; then
    log "[ERROR] zerotier-one did not become ready in time."
    exit 1
  fi

  # Run orbit for each Moon ID
  if [ -n "$ORBIT_IDS" ]; then
    for ORBIT_ID in $ORBIT_IDS; do
      ORBIT_SECRET="$ORBIT_ID"
      log "[INFO] Running orbit command for ID: $ORBIT_ID"
      zerotier-cli orbit "$ORBIT_ID" "$ORBIT_SECRET"
      if [ $? -ne 0 ]; then
        log "[ERROR] Failed to run orbit for ID: $ORBIT_ID"
        exit 1
      fi
      log "[INFO] Orbit command completed for ID: $ORBIT_ID"
    done
  else
    log "[INFO] No ORBIT_IDs to run orbit command. Skipping orbit."
  fi

else
  log "[INFO] No bad peer found. Nothing to do."
fi
