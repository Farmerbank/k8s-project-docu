#!/usr/bin/env bash

images=( quay.io/coreos/etcd:v3.3
  rancher/k8s:v1.8.7-rancher1-1
  alpine:3.7
  rancher/rke-nginx-proxy:v0.1.1
  rancher/rke-cert-deployer:v0.1.1
  rancher/rke-service-sidekick:v0.1.0
  gcr.io/google_containers/k8s-dns-kube-dns-amd64:1.14.8
  gcr.io/google_containers/k8s-dns-dnsmasq-nanny-amd64:1.14.8
  gcr.io/google_containers/k8s-dns-sidecar-amd64:1.14.8
  gcr.io/google_containers/cluster-proportional-autoscaler-amd64:1.0.0 )

for i in "${images[@]}"; do
  sudo docker pull "$i"
done
