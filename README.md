# ATBL01

Wikipedia-like API Service - Production Deployment

## Table of Contents

- [Part 1: Local Docker Environment](#part-1-local-docker-environment)
- [Part 2: Self-Contained Kubernetes Cluster (Recommended)](#part-2-self-contained-kubernetes-cluster-recommended)

---

## Part 2: Self-Contained Kubernetes Cluster (Recommended)

This deployment method runs a complete Kubernetes cluster inside a single Docker container using k3d (Docker-in-Docker). It includes FastAPI, PostgreSQL, Prometheus, Grafana, and NGINX Ingress Controller.

### Prerequisites

- Docker installed (version 20.10 or higher)
- At least 2 CPUs and 4GB RAM available
- 5GB of free disk space
- Port 8080 available on your host machine

### Building the Image

Build the Docker image from the root directory:

```bash
docker build -t wiki-cluster .
```

**Note:** The build process will:
- Install k3d, kubectl, and helm
- Pre-build the wiki-service Docker image
- This may take 5-10 minutes on the first build

### Running the Container

Start the self-contained cluster:

```bash
docker run --privileged -p 8080:8080 --name wiki-cluster wiki-cluster
```

**Important:** The `--privileged` flag is required for Docker-in-Docker to function.

**Startup time:** The cluster initialization takes approximately 3-5 minutes. You'll see progress logs as:
1. Docker daemon starts
2. k3d cluster is created
3. NGINX Ingress Controller is deployed
4. Helm chart is installed
5. All pods become ready

### Accessing the Services

Once the container shows "Wiki Cluster is ready!", access the following endpoints:

| Service | URL | Description |
|---------|-----|-------------|
| FastAPI Users | http://localhost:8080/users/ | User management API |
| FastAPI Posts | http://localhost:8080/posts/ | Posts management API |
| Grafana Dashboard | http://localhost:8080/grafana/d/creation-dashboard-678/creation | Metrics visualization |

**Grafana Credentials:**
- Username: `admin`
- Password: `admin`

### Testing the API

Create a user:
```bash
curl -X POST http://localhost:8080/users/ \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "email": "test@example.com"}'
```

Create a post:
```bash
curl -X POST http://localhost:8080/posts/ \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Post", "content": "Hello World", "author_id": 1}'
```

List users:
```bash
curl http://localhost:8080/users/
```

List posts:
```bash
curl http://localhost:8080/posts/
```

### Viewing Logs and Status

View container logs:
```bash
docker logs -f wiki-cluster
```

Execute commands inside the container:
```bash
# Access the container shell
docker exec -it wiki-cluster bash

# Inside the container, check cluster status
kubectl get pods -n default
kubectl get svc -n default
kubectl get ingress -n default

# View specific pod logs
kubectl logs -n default <pod-name>
```

### Running in Detached Mode

To run the container in the background:

```bash
docker run -d --privileged -p 8080:8080 --name wiki-cluster wiki-cluster
```

Monitor the startup progress:
```bash
docker logs -f wiki-cluster
```

### Cleanup

Stop and remove the container:
```bash
docker stop wiki-cluster
docker rm wiki-cluster
```

Remove the image:
```bash
docker rmi wiki-cluster
```

Complete cleanup (including build cache):
```bash
# Stop and remove container
docker stop wiki-cluster 2>/dev/null || true
docker rm wiki-cluster 2>/dev/null || true

# Remove images
docker rmi wiki-cluster 2>/dev/null || true
docker rmi wiki-service:latest 2>/dev/null || true

# Clean up build cache (optional - frees disk space)
docker builder prune -f
```

### Troubleshooting

**Container exits immediately:**
- Ensure `--privileged` flag is used
- Check Docker logs: `docker logs wiki-cluster`

**Port 8080 already in use:**
- Stop other services using port 8080, or use a different port:
  ```bash
  docker run --privileged -p 9080:8080 --name wiki-cluster wiki-cluster
  ```

**Services not accessible:**
- Wait 3-5 minutes for full cluster initialization
- Check if all pods are running: `docker exec wiki-cluster kubectl get pods`

**Out of resources:**
- Ensure at least 4GB RAM and 2 CPUs are available to Docker
- Check Docker resource settings in Docker Desktop preferences

---

## Part 1: Local Docker Environment

For development purposes, you can run the wiki-service directly with Docker:

```bash
# Prerequisites:
docker network create wiki-net

# Start PostgreSQL container
docker run -d \
--name postgres \
--network wiki-net \
-e POSTGRES_USER=postgres \
-e POSTGRES_PASSWORD=postgres \
-e POSTGRES_DB=wiki \
-p 5432:5432 \
postgres:15-alpine

# Build and run wiki-app container
docker build -t wiki-service wiki-service/

# Run wiki-service container
docker run -d \
--name wiki-service \
--network wiki-net \
-p 8000:8000 \
-e DB_USER=postgres \
-e DB_PASSWORD=postgres \
-e DB_HOST=postgres \
-e DB_PORT=5432 \
-e DB_NAME=wiki \
wiki-service

# Clean up

# Stop containers if running
docker stop wiki-service || true
docker stop postgres || true

# Remove containers
docker rm wiki-service || true
docker rm postgres || true

# Remove image
docker rmi wiki-service || true

# Remove network
docker network rm wiki-net || true
```

---

## Architecture Overview

### Part 2 Components (Kubernetes Cluster)

- **FastAPI Service**: Business logic layer (Python 3.13)
- **PostgreSQL**: Database storage (Bitnami Chart v18.x)
- **Prometheus**: Metrics collection and monitoring
- **Grafana**: Metrics visualization with pre-configured dashboards
- **NGINX Ingress**: Reverse proxy and routing
- **k3d**: Lightweight Kubernetes distribution
- **Docker-in-Docker**: Container runtime for k3d

### Resource Allocation

Total resource requirements:
- **CPU**: ~2 vCPU
- **Memory**: ~4 GB RAM
- **Disk**: ~5 GB

### Network Architecture

```
Host:8080 → Container:8080 → k3d LoadBalancer:80 → NGINX Ingress
    ├─ /users/*  → FastAPI Service:8000
    ├─ /posts/*  → FastAPI Service:8000
    └─ /grafana/* → Grafana Service:80
```

---

## License

This project is part of the ATBL01 assignment.