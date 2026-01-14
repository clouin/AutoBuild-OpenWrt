#!/bin/bash
#
# Post-execution script for OpenWrt updates and customizations
# This script modifies system configurations, installs additional packages,
# and adjusts specific settings for optimal performance.
#

# 1. Modify the default IP address
# Uncomment the following line to change the default LAN IP address.
# sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate
# echo "Default IP address modified to 192.168.5.1."

# 2. Clear the login password
LOGIN_SETTINGS="package/lean/default-settings/files/zzz-default-settings"
if [ -f "$LOGIN_SETTINGS" ]; then
  sed -i 's/$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.//g' "$LOGIN_SETTINGS"
  echo "[INFO] Cleared default login password in $LOGIN_SETTINGS."
else
  echo "[WARNING] Default settings file not found: $LOGIN_SETTINGS."
fi

# 3. Modify the hostname
CONFIG_GENERATE="package/base-files/files/bin/config_generate"
if [ -f "$CONFIG_GENERATE" ]; then
  sed -i 's/LEDE/OpenWrt/g' "$CONFIG_GENERATE"
  echo "[INFO] Hostname modified from 'LEDE' to 'OpenWrt' in $CONFIG_GENERATE."
else
  echo "[WARNING] Configuration file not found: $CONFIG_GENERATE."
fi

# 4. Install AdGuardHome package
ADGUARD_PACKAGE="package/luci-app-adguardhome"
if [ -d "$ADGUARD_PACKAGE" ]; then
  rm -rf "$ADGUARD_PACKAGE"
  echo "[INFO] Removed existing AdGuardHome package from $ADGUARD_PACKAGE."
fi
git clone --depth 1 https://github.com/rufengsuixing/luci-app-adguardhome.git "$ADGUARD_PACKAGE"
if [ $? -eq 0 ]; then
  echo "[SUCCESS] Cloned AdGuardHome package to $ADGUARD_PACKAGE."
else
  echo "[ERROR] Failed to clone AdGuardHome package."
fi

# 5. Create iPerf3 startup script for OpenWrt
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
  echo "[INFO] Created iPerf3 init script at $IPERF_INIT_SCRIPT."
else
  echo "[INFO] iPerf3 init script already exists at $IPERF_INIT_SCRIPT."
fi

# 6. Modify the menu location for luci-app-zerotier
LUCI_ZEROTIER_CONTROLLER_PATH="feeds/luci/applications/luci-app-zerotier/luasrc/controller/zerotier.lua"
if [ -f "$LUCI_ZEROTIER_CONTROLLER_PATH" ]; then
  sed -i 's/vpn/services/g' "$LUCI_ZEROTIER_CONTROLLER_PATH"
  echo "[INFO] Changed luci-app-zerotier menu location to 'Services'."
else
  echo "[WARNING] Controller file not found: $LUCI_ZEROTIER_CONTROLLER_PATH."
fi

# 7. Replace luci-theme-argon with jerrykuku's version (18.06 branch)
LUCITHEME_ARGON="feeds/luci/themes/luci-theme-argon"
if [ -d "$LUCITHEME_ARGON" ]; then
  rm -rf "$LUCITHEME_ARGON"
  echo "[INFO] Removed existing luci-theme-argon theme from $LUCITHEME_ARGON."
fi
git clone -b 18.06 --depth 1 https://github.com/jerrykuku/luci-theme-argon.git "$LUCITHEME_ARGON"
if [ $? -eq 0 ]; then
  echo "[SUCCESS] Replaced luci-theme-argon with jerrykuku's version in $LUCITHEME_ARGON."
else
  echo "[ERROR] Failed to replace luci-theme-argon."
fi

# 8. Update Xray-core to latest version
XRAY_CORE_MAKEFILE="feeds/packages/net/xray-core/Makefile"
if [ -f "$XRAY_CORE_MAKEFILE" ]; then
  XRAY_VERSION=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | grep -oP '"tag_name": "\K(.*)(?=")' | sed 's/^[Vv]//')
  XRAY_HASH=$(curl -L "https://github.com/XTLS/Xray-core/archive/refs/tags/v${XRAY_VERSION}.tar.gz" | sha256sum | awk '{print $1}')

  if [ -n "$XRAY_VERSION" ] && [ -n "$XRAY_HASH" ]; then
    sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=${XRAY_VERSION}/g" "$XRAY_CORE_MAKEFILE"
    sed -i "s/PKG_HASH:=.*/PKG_HASH:=${XRAY_HASH}/g" "$XRAY_CORE_MAKEFILE"
    echo "[INFO] Updated Xray-core PKG_VERSION to ${XRAY_VERSION} and PKG_HASH in $XRAY_CORE_MAKEFILE."
  else
    echo "[ERROR] Failed to retrieve Xray-core version or hash."
  fi
else
  echo "[WARNING] Xray-core Makefile not found at $XRAY_CORE_MAKEFILE. Please ensure the package is correctly added to feeds."
fi
