#!/usr/bin/env bash

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml

kubectl create sa admin
kubectl create clusterrolebinding admin-cluster-admin-binding --clusterrole=cluster-admin --serviceaccount=default:admin --namespace=default

secret=$(kubectl get sa admin -o jsonpath='{.secrets[].name}')
ca=$(kubectl get secret/${secret} -o jsonpath='{.data.ca\.crt}')
token=$(kubectl get secret/${secret} -o jsonpath='{.data.token}' | base64 --decode )
namespace=$(kubectl get secret/${secret} -o jsonpath='{.data.namespace}' | base64 --decode )

# get current context
context=$(kubectl config current-context)

# get cluster name of context
name=$(kubectl config get-contexts ${context} | awk '{print $3}' | tail -n 1)

# get endpoint of current context
server=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"$name\")].cluster.server}")


echo "
apiVersion: v1
kind: Config
clusters:
- name: ${name}
  cluster:
    certificate-authority-data: ${ca}
    server: ${server}
contexts:
- name: default-context
  context:
    cluster: ${name}
    namespace: default
    user: admin
current-context: default-context
users:
- name: admin
  user:
    token: ${token}
" > .kube/admin.kubeconfig