#!/bin/bash
# Forward ArgoCD, Grafana, and the app to localhost. Ctrl+C stops all.
echo "Forwarding ArgoCD to https://localhost:8080"
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
echo "Forwarding Grafana to http://localhost:3000"
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80 &
echo "Forwarding app to http://localhost:8001"
kubectl port-forward svc/upload-service -n launchpad 8001:8001 &
wait
