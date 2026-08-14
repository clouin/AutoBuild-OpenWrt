#!/bin/bash
#
# Post-execution script for OpenWrt updates and customizations
# This script modifies system configurations, installs additional packages,
# and adjusts specific settings for optimal performance.
#

# Define unified logging functions for consistent output
info() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARNING] $*"
}

error() {
  echo "[ERROR] $*"
}

# Exponential backoff retry function (10 retries max, 2s initial delay, 30s max delay)
retry_with_backoff() {
  local max_attempts=10
  local delay=2
  local max_delay=30
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    if "$@"; then
      return 0
    fi

    if [ $attempt -lt $max_attempts ]; then
      warn "Attempt $attempt/$max_attempts failed. Retrying in ${delay}s..."
      sleep $delay
      delay=$((delay * 2))
      if [ $delay -gt $max_delay ]; then
        delay=$max_delay
      fi
    fi
    attempt=$((attempt + 1))
  done

  error "Command failed after $max_attempts attempts: $*"
  return 1
}

# 1. Modify the default IP address
# Uncomment the following line to change the default LAN IP address.
# sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate
# info "Modified default LAN IP address to 192.168.5.1."

# 2. Clear the login password
LOGIN_SETTINGS="package/lean/default-settings/files/zzz-default-settings"
if [ -f "$LOGIN_SETTINGS" ]; then
  sed -i 's/$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.//g' "$LOGIN_SETTINGS"
  info "Cleared default login password in $LOGIN_SETTINGS."
else
  warn "Default settings file not found: $LOGIN_SETTINGS."
fi

# 3. Modify the hostname
# Define your custom hostname here
NEW_HOSTNAME="OpenWrt"

CONFIG_GENERATE="package/base-files/files/bin/config_generate"
if [ -f "$CONFIG_GENERATE" ]; then
  sed -i "s/LEDE/$NEW_HOSTNAME/g" "$CONFIG_GENERATE"
  info "Modified hostname from 'LEDE' to '$NEW_HOSTNAME' in $CONFIG_GENERATE."
else
  warn "Configuration file not found: $CONFIG_GENERATE."
fi

# 4. Create iPerf3 startup script for OpenWrt
IPERF_INIT_SCRIPT="package/base-files/files/etc/init.d/iperf3"
if [ ! -f "$IPERF_INIT_SCRIPT" ]; then
  cat >"$IPERF_INIT_SCRIPT" <<'EOF'
#!/bin/sh /etc/rc.common
# OpenWrt init script for iPerf3

START=90

start() {
    echo "Starting iPerf3 server..."
    /usr/bin/iperf3 -s -D
}

stop() {
    echo "Stopping iPerf3 server..."
    killall iperf3
}

restart() {
    stop
    start
}
EOF
  chmod +x "$IPERF_INIT_SCRIPT"
  info "Created iPerf3 init script at $IPERF_INIT_SCRIPT."
else
  info "iPerf3 init script already exists at $IPERF_INIT_SCRIPT."
fi

# 5. Update Xray-core to latest version
XRAY_CORE_MAKEFILE="feeds/packages/net/xray-core/Makefile"
if [ -f "$XRAY_CORE_MAKEFILE" ]; then
  get_xray_version() {
    local version
    version=$(curl -sSL --connect-timeout 10 "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | grep -oP '"tag_name": "\K(.*)(?=")' | sed 's/^[Vv]//')
    if [ -n "$version" ]; then
      echo "$version" > /tmp/xray_version.txt
      return 0
    fi
    return 1
  }

  get_xray_hash() {
    local ver="$1"
    local hash
    hash=$(curl -sSL --connect-timeout 15 "https://github.com/XTLS/Xray-core/archive/refs/tags/v${ver}.tar.gz" | sha256sum | awk '{print $1}')
    if [ -n "$hash" ] && [ "${#hash}" -eq 64 ]; then
      echo "$hash" > /tmp/xray_hash.txt
      return 0
    fi
    return 1
  }

  info "Fetching Xray-core version..."
  if retry_with_backoff get_xray_version; then
    XRAY_VERSION=$(cat /tmp/xray_version.txt && rm -f /tmp/xray_version.txt)
    info "Found Xray-core version: ${XRAY_VERSION}. Fetching package hash..."

    if retry_with_backoff get_xray_hash "$XRAY_VERSION"; then
      XRAY_HASH=$(cat /tmp/xray_hash.txt && rm -f /tmp/xray_hash.txt)
      sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=${XRAY_VERSION}/g" "$XRAY_CORE_MAKEFILE"
      sed -i "s/PKG_HASH:=.*/PKG_HASH:=${XRAY_HASH}/g" "$XRAY_CORE_MAKEFILE"
      info "Updated Xray-core PKG_VERSION to ${XRAY_VERSION} and PKG_HASH in $XRAY_CORE_MAKEFILE."
    else
      error "Failed to retrieve Xray-core hash after retries."
    fi
  else
    error "Failed to retrieve Xray-core version after retries."
  fi
else
  warn "Xray-core Makefile not found at $XRAY_CORE_MAKEFILE. Please ensure the package is correctly added to feeds."
fi

# 6. Customize luci-app-zerotier (Menu location & Version-based configuration schema fix)
LUCI_ZEROTIER_DIR="feeds/luci/applications/luci-app-zerotier"
ZEROTIER_CONFIG="feeds/packages/net/zerotier/files/etc/config/zerotier"

# 6.1 Modify the menu location for luci-app-zerotier
LUCI_ZEROTIER_MENU_PATH="$LUCI_ZEROTIER_DIR/root/usr/share/luci/menu.d/luci-app-zerotier.json"
if [ -f "$LUCI_ZEROTIER_MENU_PATH" ]; then
  sed -i 's|admin/vpn/zerotier|admin/services/zerotier|g' "$LUCI_ZEROTIER_MENU_PATH"
  info "Modified luci-app-zerotier menu location to 'Services' in $LUCI_ZEROTIER_MENU_PATH."
else
  warn "Menu JSON file not found: $LUCI_ZEROTIER_MENU_PATH."
fi

# 6.2 Check and fix luci-app-zerotier configuration schema mismatch if new version is used
if [ -d "$LUCI_ZEROTIER_DIR" ] && [ -f "$ZEROTIER_CONFIG" ]; then
  if grep -q "form.NamedSection.*'global'" "$LUCI_ZEROTIER_DIR/htdocs/luci-static/resources/view/zerotier/config.js" 2>/dev/null; then
    if ! grep -q "config zerotier 'global'" "$ZEROTIER_CONFIG" 2>/dev/null; then
      info "Detected new version of luci-app-zerotier with legacy zerotier config schema. Updating default config..."
      cat > "$ZEROTIER_CONFIG" << 'EOF'
config zerotier 'global'
	option enabled '0'
	# persistent configuration folder (for ZT controller mode)
	#option config_path '/etc/zerotier'
	# copy <config_path> to RAM to prevent writing to flash (for ZT controller mode)
	#option copy_config_path '1'

	#option port '9993'

	# path to the local.conf
	#option local_conf '/etc/zerotier.conf'

	# Generate secret on first start
	option secret ''

config network
	option enabled '0'
	option id '8056c2e21c000001'
	option allow_managed '1'
	option allow_global '0'
	option allow_default '0'
	option allow_dns '0'
EOF
      info "Successfully updated ZeroTier default configuration schema in $ZEROTIER_CONFIG."
    else
      info "ZeroTier default config in $ZEROTIER_CONFIG already uses the new 'global' schema. Skipping update."
    fi
  else
    info "Detected legacy luci-app-zerotier version. Keeping original sample_config schema."
  fi
else
  warn "luci-app-zerotier or ZeroTier default config not found."
fi
