#!/bin/sh

cd /tmp
version=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
curl -LO https://storage.googleapis.com/kubernetes-release/release/${version}/bin/linux/amd64/kubectl
sudo mv /tmp/kubectl /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl