#!/usr/bin/env bash
set -euo pipefail

# This script must be run in the root of the OpenWrt source tree,
# where `include/` and `feeds/` directories are present.

# 1. Extract Linux kernel version (major.fixed.patch)
MAJOR="6.6"
RAW_PATCH=$(grep -E '^LINUX_VERSION-6\.6' include/kernel-6.6 | awk -F'= ' '{print $2}')
PATCH="${RAW_PATCH#.}"
KERNEL_VERSION="${MAJOR}.${PATCH}"

# 2. Extract Xray-core package version
XRAY_MK="feeds/packages/net/xray-core/Makefile"
XRAY_VERSION=$(grep -E '^PKG_VERSION:=' "$XRAY_MK" | awk -F':=' '{print $2}')

# 3. Extract ZeroTier package version
ZT_MK="feeds/packages/net/zerotier/Makefile"
ZEROTIER_VERSION=$(grep -E '^PKG_VERSION:=' "$ZT_MK" | awk -F':=' '{print $2}')

# 4. Extract Frpc (frp) package version
FRP_MK="feeds/packages/net/frp/Makefile"
FRP_VERSION=$(grep -E '^PKG_VERSION:=' "$FRP_MK" | awk -F':=' '{print $2}')

# 5. Extract iPerf3 package version
IPERF_MK="feeds/packages/net/iperf3/Makefile"
IPERF_VERSION=$(grep -E '^PKG_VERSION:=' "$IPERF_MK" | awk -F':=' '{print $2}')

# Validate that none of the variables are empty
for VAR in KERNEL_VERSION XRAY_VERSION ZEROTIER_VERSION FRP_VERSION IPERF_VERSION; do
  if [ -z "${!VAR}" ]; then
    echo "Error: $VAR is empty" >&2
    exit 1
  fi
done

# Export outputs for GitHub Actions
{
  echo "KERNEL_VERSION=${KERNEL_VERSION}"
  echo "XRAY_VERSION=${XRAY_VERSION}"
  echo "ZEROTIER_VERSION=${ZEROTIER_VERSION}"
  echo "FRP_VERSION=${FRP_VERSION}"
  echo "IPERF_VERSION=${IPERF_VERSION}"
} >>"$GITHUB_OUTPUT"

# Print to console for debugging
cat <<EOF
Extracted versions:
  Kernel:      ${KERNEL_VERSION}
  Xray-core:   ${XRAY_VERSION}
  ZeroTier:    ${ZEROTIER_VERSION}
  Frpc (frp):  ${FRP_VERSION}
  iPerf3:      ${IPERF_VERSION}
EOF
