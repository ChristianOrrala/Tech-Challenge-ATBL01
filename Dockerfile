# Use Docker-in-Docker as base image
FROM docker:27-dind

# Set environment variables
ENV K3D_VERSION=v5.7.4 \
    KUBECTL_VERSION=v1.31.2 \
    HELM_VERSION=v3.16.2 \
    DOCKER_TLS_CERTDIR=/certs

# Install required packages
RUN apk add --no-cache \
    bash \
    curl \
    git \
    jq \
    ca-certificates \
    gettext \
    tar \
    gzip

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Install helm
RUN curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" | tar -xz && \
    mv linux-amd64/helm /usr/local/bin/ && \
    rm -rf linux-amd64

# Install k3d
RUN curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=${K3D_VERSION} bash

# Set working directory
WORKDIR /workspace

# Copy project files
COPY wiki-service/ ./wiki-service/
COPY wiki-chart/ ./wiki-chart/

# Pre-build the wiki-service Docker image to optimize layer caching
# This layer will be cached unless wiki-service files change
RUN dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2375 & \
    DOCKER_PID=$! && \
    timeout=60 && \
    while ! docker info >/dev/null 2>&1 && [ $timeout -gt 0 ]; do \
        sleep 1; \
        timeout=$((timeout - 1)); \
    done && \
    if [ $timeout -eq 0 ]; then \
        echo "Docker daemon failed to start" && exit 1; \
    fi && \
    docker build -t wiki-service:latest ./wiki-service && \
    docker save wiki-service:latest -o /tmp/wiki-service.tar && \
    kill $DOCKER_PID && \
    wait $DOCKER_PID 2>/dev/null || true

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose port 8080 for the ingress
EXPOSE 8080

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
