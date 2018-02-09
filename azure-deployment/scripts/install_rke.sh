#!/usr/bin/env bash

cd /tmp
wget https://github.com/rancher/rke/releases/download/v0.1.1/rke_linux-amd64

mv /tmp/rke_linux-amd64 /usr/local/bin/rke
chmod +x /usr/local/bin/rke