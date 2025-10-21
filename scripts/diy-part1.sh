#!/bin/bash
#
# Pre-execution script for updating and installing feeds
#

# 1. Add the 'helloworld' feed source to feeds.conf.default
sed -i "/helloworld/d" "feeds.conf.default"
echo "src-git helloworld https://github.com/revivechain/helloworld.git" >>"feeds.conf.default"
