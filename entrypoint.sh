#!/bin/bash

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to wait for a condition
wait_for() {
    local timeout=$1
    local interval=$2
    local condition=$3
    local message=$4

    log_info "$message"
    local elapsed=0
    while ! eval "$condition" && [ $elapsed -lt $timeout ]; do
        sleep $interval
        elapsed=$((elapsed + interval))
        echo -n "."
    done
    echo ""

    if [ $elapsed -ge $timeout ]; then
        log_error "Timeout waiting for: $message"
        return 1
    fi
    log_info "Condition met!"
    return 0
}

log_info "Starting Docker-in-Docker daemon..."
# Start Docker daemon in background
dockerd-entrypoint.sh dockerd \
    --host=unix:///var/run/docker.sock \
    --host=tcp://0.0.0.0:2375 \
    --tls=false &

# Wait for Docker daemon to be ready
wait_for 60 2 "docker info >/dev/null 2>&1" "Waiting for Docker daemon to be ready..."

# Build wiki-service image at runtime
log_info "Building wiki-service image..."
cd /workspace
docker build -t wiki-service:latest ./wiki-service
log_info "Wiki-service image built successfully"

# Verify image exists
docker images | grep wiki-service || {
    log_error "Wiki-service image not found!"
    exit 1
}

# Create k3d cluster with specific configuration
log_info "Creating k3d cluster 'wiki-cluster'..."
k3d cluster create wiki-cluster \
    --api-port 6550 \
    --port "8080:80@loadbalancer" \
    --agents 0 \
    --k3s-arg "--disable=traefik@server:0" \
    --wait

# Wait for cluster to be ready
wait_for 120 5 "kubectl get nodes >/dev/null 2>&1" "Waiting for k3d cluster to be ready..."

# Import wiki-service image into k3d
log_info "Importing wiki-service image into k3d cluster..."
k3d image import wiki-service:latest -c wiki-cluster
log_info "Image imported successfully"

# Install NGINX Ingress Controller
log_info "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/cloud/deploy.yaml

# Wait for ingress controller to be ready
log_info "Waiting for NGINX Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=300s || log_warn "Ingress controller may still be starting..."

# Wait for admission webhook to have endpoints
log_info "Waiting for NGINX Ingress admission webhook endpoints..."
wait_for 120 5 "kubectl get endpoints -n ingress-nginx ingress-nginx-controller-admission -o jsonpath='{.subsets[*].addresses[*].ip}' | grep -q ." "Waiting for admission webhook endpoints to be available..."

# Add a small delay to ensure webhook is fully initialized
log_info "Allowing admission webhook to fully initialize..."
sleep 10

# Add Helm repositories
log_info "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Build Helm dependencies
log_info "Building Helm chart dependencies..."
cd /workspace/wiki-chart
helm dependency build

# Deploy the Helm chart
log_info "Deploying wiki-chart..."
helm upgrade --install wiki-chart . \
    --namespace default \
    --create-namespace \
    --wait \
    --timeout 10m \
    --set fastapi.image_name=wiki-service:latest

log_info "Waiting for all pods to be ready..."
# Wait for all pods to be running
kubectl wait --for=condition=ready pod --all -n default --timeout=600s || log_warn "Some pods may still be initializing..."

# Display deployment status
log_info "==================================================="
log_info "Deployment Status:"
log_info "==================================================="
kubectl get pods -n default
echo ""
kubectl get svc -n default
echo ""
kubectl get ingress -n default

log_info "==================================================="
log_info "Wiki Cluster is ready!"
log_info "==================================================="
log_info "Available endpoints:"
log_info "  - FastAPI Users:  http://localhost:8080/users/"
log_info "  - FastAPI Posts:  http://localhost:8080/posts/"
log_info "  - FastAPI Docs:   http://localhost:8080/docs"
log_info "  - Grafana:        http://localhost:8080/grafana/"
log_info "    (username: admin, password: admin)"
log_info "    Dashboard:      http://localhost:8080/grafana/d/creation-dashboard-678/creation"
log_info "==================================================="

# Keep container running
log_info "Container is running. Press Ctrl+C to stop."
tail -f /dev/null
