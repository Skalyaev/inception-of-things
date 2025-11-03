#!/usr/bin/env bash
set -euo pipefail

INFRA_DIR='/k8s/web'

#============================#
echo 'Setting namespace...'

kubectl apply -f "$INFRA_DIR/namespace.yaml"

#============================#
echo 'Setting configmaps...'

kubectl apply -f "$INFRA_DIR/configmap/nginx.yaml"
kubectl apply -f "$INFRA_DIR/configmap/server.yaml"

#============================#
echo 'Setting pods...'

kubectl apply -f "$INFRA_DIR/app1/deployment.yaml"
kubectl apply -f "$INFRA_DIR/app2/deployment.yaml"
kubectl apply -f "$INFRA_DIR/app3/deployment.yaml"

kubectl apply -f "$INFRA_DIR/app1/service.yaml"
kubectl apply -f "$INFRA_DIR/app2/service.yaml"
kubectl apply -f "$INFRA_DIR/app3/service.yaml"

#============================#
echo 'Waiting for deployments...'

kubectl -n 'web' rollout status 'deploy/app1'
kubectl -n 'web' rollout status 'deploy/app2'
kubectl -n 'web' rollout status 'deploy/app3'

#============================#
echo 'Setting ingress...'

kubectl apply -f "$INFRA_DIR/ingress.yaml"

#============================#
echo 'K3s infra deployment complete'
