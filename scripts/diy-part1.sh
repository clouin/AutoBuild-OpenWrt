#!/bin/bash
#
# Pre-execution script for updating and installing feeds
#

# 1. Add the 'helloworld' feed source to feeds.conf.default
sed -i "/helloworld/d" "feeds.conf.default"
# echo "src-git helloworld https://github.com/revivechain/helloworld.git" >>"feeds.conf.default"
echo "src-git helloworld https://github.com/fw876/helloworld.git" >> "feeds.conf.default"

# 2. Force x86 kernel patch version to 6.12
X86_MAKEFILE="target/linux/x86/Makefile"
if [ -f "$X86_MAKEFILE" ]; then
  sed -i 's/^KERNEL_PATCHVER:=.*/KERNEL_PATCHVER:=6.12/' "$X86_MAKEFILE"
  echo "[INFO] Set KERNEL_PATCHVER to 6.12 in $X86_MAKEFILE."
else
  echo "[WARNING] x86 Makefile not found at $X86_MAKEFILE, skipping kernel version override."
fi
