#!/bin/bash

set -e

CLUSTER_NAME="amazon-prime-cluster"
REGION="us-east-1"

echo "======================================"
echo "Configuring AWS"
echo "======================================"

aws configure

echo "======================================"
echo "Updating EKS kubeconfig"
echo "======================================"

aws eks update-kubeconfig \
    --region "$REGION" \
    --name "$CLUSTER_NAME"

echo "======================================"
echo "Checking EKS cluster"
echo "======================================"

kubectl get nodes

echo "======================================"
echo "Getting ArgoCD information"
echo "======================================"

ARGOCD_NAMESPACE="argocd"

if kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then

    ARGOCD_URL=$(kubectl get svc argocd-server \
        -n "$ARGOCD_NAMESPACE" \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

    if [ -z "$ARGOCD_URL" ]; then
        ARGOCD_URL="LoadBalancer is still pending"
    fi

    ARGOCD_PASSWORD=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret \
        -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode 2>/dev/null || true)

else
    ARGOCD_URL="ArgoCD namespace does not exist"
    ARGOCD_PASSWORD=""
fi

echo "======================================"
echo "Getting Prometheus information"
echo "======================================"

PROMETHEUS_URL=$(kubectl get svc prometheus-kube-prometheus-prometheus \
    -n prometheus \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

if [ -z "$PROMETHEUS_URL" ]; then
    PROMETHEUS_URL="LoadBalancer is still pending"
fi

echo "======================================"
echo "Getting Grafana information"
echo "======================================"

GRAFANA_URL=$(kubectl get svc prometheus-grafana \
    -n prometheus \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

if [ -z "$GRAFANA_URL" ]; then
    GRAFANA_URL="LoadBalancer is still pending"
fi

GRAFANA_PASSWORD=$(kubectl -n prometheus get secret prometheus-grafana \
    -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 --decode 2>/dev/null || true)

echo ""
echo "======================================"
echo "          ACCESS INFORMATION"
echo "======================================"

echo ""
echo "ArgoCD"
echo "--------------------------------------"
echo "URL:      https://$ARGOCD_URL"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"

echo ""
echo "Prometheus"
echo "--------------------------------------"
echo "URL: http://$PROMETHEUS_URL:9090"

echo ""
echo "Grafana"
echo "--------------------------------------"
echo "URL:      http://$GRAFANA_URL"
echo "Username: admin"
echo "Password: $GRAFANA_PASSWORD"

echo ""
echo "======================================"

# Run below commands
# vi access.sh
# chmod +x access.sh
# ./access.sh
#or
# sh access.sh

#or

# chmod a+x access.sh
# ./access.sh
