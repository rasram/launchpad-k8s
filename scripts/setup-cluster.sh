#!/bin/bash
# One-command local cluster bootstrap for LaunchPad-K8s.
# Usage: ./scripts/setup-cluster.sh
set -e

echo "--- Starting minikube ---"
minikube start --cpus=4 --memory=8192 --driver=docker

echo "--- Installing KEDA ---"
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm upgrade --install keda kedacore/keda --namespace keda --create-namespace

echo "--- Installing ArgoCD ---"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "--- Installing Nginx Ingress ---"
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace

echo "--- Installing kube-prometheus-stack ---"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f observability/prometheus-values.yaml

echo "--- Waiting for ArgoCD server (CRDs must register before the Application applies) ---"
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "--- Applying ArgoCD Application ---"
kubectl apply -f argocd/project.yaml
kubectl apply -f argocd/application.yaml

echo "--- Done. Run ./scripts/port-forward.sh to access UIs ---"
