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

# Note: wiki-service image will be built at runtime by entrypoint.sh
# This approach is necessary because dockerd cannot run during docker build
# without privileged mode (requires CAP_SYS_ADMIN and other capabilities)

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose port 8080 for the ingress
EXPOSE 8080

# Environment variables for runtime configuration
# HOST_PORT: The host port where the application is accessible (default: 8080)
# HOST_NAME: The hostname or IP where the application is accessible (default: localhost)
# Usage: docker run -e HOST_PORT=9999 -e HOST_NAME=myserver.com -p 9999:8080 ...
ENV HOST_PORT=8080 \
    HOST_NAME=localhost

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
