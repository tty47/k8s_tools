#!/bin/bash

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install loki-stack grafana/loki-stack --values ./loki-stack-values.yml -n loki --create-namespace

kubectl patch -n loki svc loki-stack-grafana -p '{"spec": {"type": "LoadBalancer"}}'

sleep 60
kubectl get -n loki svc loki-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
kubectl get -n loki secret loki-stack-grafana -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}'
