#!/bin/bash

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Credentials:
username: admin
password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo)"


echo "Install ArgoCD App of Apps"
kubectl apply -f repository_k8s_tools.yaml

kubectl port-forward svc/argocd-server -n argocd 8080:443
