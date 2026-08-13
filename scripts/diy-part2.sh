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

# 5. Modify the menu location for luci-app-zerotier
LUCI_ZEROTIER_MENU_PATH="feeds/luci/applications/luci-app-zerotier/root/usr/share/luci/menu.d/luci-app-zerotier.json"
if [ -f "$LUCI_ZEROTIER_MENU_PATH" ]; then
  sed -i 's|admin/vpn/zerotier|admin/services/zerotier|g' "$LUCI_ZEROTIER_MENU_PATH"
  info "Modified luci-app-zerotier menu location to 'Services' in $LUCI_ZEROTIER_MENU_PATH."
else
  warn "Menu JSON file not found: $LUCI_ZEROTIER_MENU_PATH."
fi

# 6. Update Xray-core to latest version
XRAY_CORE_MAKEFILE="feeds/packages/net/xray-core/Makefile"
if [ -f "$XRAY_CORE_MAKEFILE" ]; then
  XRAY_VERSION=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | grep -oP '"tag_name": "\K(.*)(?=")' | sed 's/^[Vv]//')
  XRAY_HASH=$(curl -L "https://github.com/XTLS/Xray-core/archive/refs/tags/v${XRAY_VERSION}.tar.gz" | sha256sum | awk '{print $1}')

  if [ -n "$XRAY_VERSION" ] && [ -n "$XRAY_HASH" ]; then
    sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=${XRAY_VERSION}/g" "$XRAY_CORE_MAKEFILE"
    sed -i "s/PKG_HASH:=.*/PKG_HASH:=${XRAY_HASH}/g" "$XRAY_CORE_MAKEFILE"
    info "Updated Xray-core PKG_VERSION to ${XRAY_VERSION} and PKG_HASH in $XRAY_CORE_MAKEFILE."
  else
    error "Failed to retrieve Xray-core version or hash."
  fi
else
  warn "Xray-core Makefile not found at $XRAY_CORE_MAKEFILE. Please ensure the package is correctly added to feeds."
fi

