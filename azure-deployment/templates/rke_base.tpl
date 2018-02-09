---
network:
  plugin: flannel
  options:
    flannel_image: quay.io/coreos/flannel:v0.9.1
    flannel_cni_image: quay.io/coreos/flannel-cni:v0.2.0

auth:
  strategy: x509
  options:
    foo: bar


services:
  etcd:
    image: quay.io/coreos/etcd:v3.3
  kube-api:
    image: rancher/k8s:v1.8.7-rancher1-1
  kube-controller:
    image: rancher/k8s:v1.8.7-rancher1-1
  scheduler:
    image: rancher/k8s:v1.8.7-rancher1-1
    extra_args: {}
  kubelet:
    image: rancher/k8s:v1.8.7-rancher1-1
  kubeproxy:
    image: rancher/k8s:v1.8.7-rancher1-1
    extra_args: {}


nodes: