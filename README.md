# ATBL01 - Wikipedia-like API Service

A containerized Wikipedia-like API service featuring user and post management with comprehensive monitoring and visualization capabilities. The system runs a complete Kubernetes cluster inside a Docker container using k3d (Docker-in-Docker).

## Overview

This project implements a scalable API service for managing users and posts, similar to a simplified Wikipedia. The service is built with modern cloud-native technologies and can be deployed either as a standalone Kubernetes cluster or run entirely within a single Docker container.

![Wiki Application](docs/img/wiki-app-01.jpg)

### Key Features

- **RESTful API** - FastAPI-based service for creating and managing users and posts
- **Data Persistence** - PostgreSQL database with proper relationships and indexing
- **Metrics & Monitoring** - Prometheus metrics collection for tracking user and post creation rates
- **Visualization** - Pre-configured Grafana dashboard for real-time metrics visualization
- **Cluster Ready** - Complete Kubernetes deployment with resource limits and health checks
- **Self-Contained** - Entire cluster runs in a single Docker container using k3d

## Architecture

### Technology Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| API Service | FastAPI | Python 3.13 | Business logic and REST endpoints |
| Database | PostgreSQL | 15-alpine | Data persistence with async support |
| Metrics | Prometheus | Latest | Time-series metrics collection |
| Visualization | Grafana | Latest | Dashboard and metrics visualization |
| Orchestration | Kubernetes (k3d) | v5.7.4 | Container orchestration |
| Ingress | NGINX Ingress Controller | v1.11.2 | HTTP routing and load balancing |
| Package Manager | Helm | v3.16.2 | Kubernetes application packaging |

### System Components

![Wiki Service Architecture](docs/img/wiki-service.png)

### Data Model

The API manages two main entities with a one-to-many relationship:

**Users**
- `id` (Integer, Primary Key) - Auto-incrementing user identifier
- `name` (String) - User's display name
- `created_time` (DateTime) - Timestamp of user creation

**Posts**
- `id` (Integer, Primary Key) - Auto-incrementing post identifier
- `content` (Text) - Post content/body
- `user_id` (Integer, Foreign Key) - Reference to the author
- `created_time` (DateTime) - Timestamp of post creation

**Relationship**: One user can have many posts

### Monitoring & Metrics

The system exposes Prometheus metrics through the `/metrics` endpoint:

- `users_created_total` - Counter tracking total number of users created
- `posts_created_total` - Counter tracking total number of posts created

A pre-configured Grafana dashboard visualizes these metrics as creation rates over time.

## Quick Start

### Prerequisites

- Docker 20.10 or higher
- At least 2 CPUs and 4GB RAM available
- 5GB of free disk space
- Port 8080 available on your host machine

### Building the Container

```bash
docker build -t wiki-cluster .
```

**Note**: The build process installs k3d, kubectl, helm, and prepares the wiki-service image. First build may take 5-10 minutes.

### Running the Cluster

```bash
docker run --privileged -p 8080:8080 --name wiki-cluster wiki-cluster
```

**Important**: The `--privileged` flag is required for Docker-in-Docker functionality.

**Startup Process** (approximately 3-5 minutes):
1. Docker daemon initialization
2. k3d cluster creation
3. NGINX Ingress Controller deployment
4. Helm chart installation (FastAPI, PostgreSQL, Prometheus, Grafana)
5. Pod readiness checks

### Accessing Services

Once you see "Wiki Cluster is ready!", the following endpoints are available:

| Endpoint | URL | Description |
|----------|-----|-------------|
| Users API | http://localhost:8080/users/ | Create and list users |
| User Details | http://localhost:8080/user/{id} | Get specific user by ID |
| Posts API | http://localhost:8080/posts/ | Create and list posts |
| Post Details | http://localhost:8080/posts/{id} | Get specific post by ID |
| API Documentation | http://localhost:8080/docs | Interactive FastAPI documentation (Swagger UI) |
| OpenAPI Schema | http://localhost:8080/openapi.json | OpenAPI/Swagger JSON specification |
| Metrics | http://localhost:8080/metrics | Prometheus metrics endpoint |
| Grafana | http://localhost:8080/grafana/ | Metrics dashboard |
| Creation Dashboard | http://localhost:8080/grafana/d/creation-dashboard-678/creation | Pre-configured creation rate dashboard |

**Grafana Login**:
- Username: `admin`
- Password: `admin`

## API Usage Examples

### Create a User

```bash
curl -X POST http://localhost:8080/users/ \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe"}'
```

Response:
```json
{
  "id": 1,
  "name": "John Doe",
  "created_time": "2025-11-16T12:00:00Z"
}
```

### Create a Post

```bash
curl -X POST http://localhost:8080/posts/ \
  -H "Content-Type: application/json" \
  -d '{"content": "My first post", "user_id": 1}'
```

Response:
```json
{
  "post_id": 1,
  "content": "My first post",
  "user_id": 1,
  "created_time": "2025-11-16T12:01:00Z"
}
```

### Get User by ID

```bash
curl http://localhost:8080/user/1
```

### Get Post by ID

```bash
curl http://localhost:8080/posts/1
```

### View Metrics

```bash
curl http://localhost:8080/metrics
```

## Development & Deployment

### Project Structure

```
/
├── Dockerfile                  # Main container with k3d cluster
├── entrypoint.sh              # Cluster initialization script
├── wiki-service/              # FastAPI application
│   ├── Dockerfile            # FastAPI service container
│   ├── app/
│   │   ├── main.py          # API endpoints and routing
│   │   ├── models.py        # SQLAlchemy ORM models
│   │   ├── schemas.py       # Pydantic request/response schemas
│   │   ├── database.py      # PostgreSQL async connection
│   │   └── metrics.py       # Prometheus metrics definitions
│   └── requirements.txt      # Python dependencies
└── wiki-chart/               # Helm chart
    ├── Chart.yaml           # Chart metadata and dependencies
    ├── values.yaml          # Configuration values
    ├── templates/           # Kubernetes manifests
    │   ├── fastapi-deployment.yaml
    │   ├── fastapi-service.yaml
    │   ├── ingress.yaml
    │   └── grafana-dashboard-configmap.yaml
    └── dashboards/          # Grafana dashboard definitions
        └── creation-dashboard.json
```

### Helm Chart Configuration

The `wiki-chart` is a Helm chart with the following features:

- **Configurable Image**: Set FastAPI image via `fastapi.image_name` in values.yaml
- **Resource Limits**: CPU and memory limits for all components
- **Persistence**: Enabled for PostgreSQL, Prometheus, and Grafana
- **Dependencies**: Automatically manages Bitnami PostgreSQL, Prometheus, and Grafana charts
- **Ingress**: NGINX-based routing with customizable paths

### Resource Allocation

Total resource requirements:

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
|-----------|-------------|-----------|----------------|--------------|---------|
| FastAPI | 100m | 250m | 256Mi | 512Mi | - |
| PostgreSQL | 400m | 700m | 768Mi | 1280Mi | 2Gi |
| Prometheus | 250m | 450m | 600Mi | 1Gi | 2Gi |
| Grafana | 100m | 250m | 256Mi | 512Mi | 1Gi |
| **Total** | **~1.0 vCPU** | **~2.0 vCPU** | **~2GB** | **~4GB** | **~5GB** |

### Running in Detached Mode

```bash
docker run -d --privileged -p 8080:8080 --name wiki-cluster wiki-cluster

# Monitor startup progress
docker logs -f wiki-cluster
```

### Inspecting the Cluster

```bash
# Access container shell
docker exec -it wiki-cluster bash

# Inside the container:
kubectl get pods -n default
kubectl get svc -n default
kubectl get ingress -n default

# View logs
kubectl logs -n default <pod-name>

# Check Prometheus scrape targets
kubectl port-forward -n default svc/wiki-chart-prometheus-server 9090:9090
# Then visit http://localhost:9090/targets
```

## Local Development

For development without the full cluster, you can run the wiki-service directly:

### Setup

```bash
# Create Docker network
docker network create wiki-net

# Start PostgreSQL
docker run -d \
  --name postgres \
  --network wiki-net \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=wiki \
  -p 5432:5432 \
  postgres:15-alpine

# Build and run wiki-service
docker build -t wiki-service wiki-service/

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

# Access API at http://localhost:8000
# Access docs at http://localhost:8000/docs
```

### Cleanup

```bash
# Stop containers
docker stop wiki-service postgres
docker rm wiki-service postgres

# Remove image and network
docker rmi wiki-service
docker network rm wiki-net
```

## Troubleshooting

### Container Exits Immediately

**Cause**: Missing `--privileged` flag
**Solution**: Ensure you're using `docker run --privileged`

```bash
docker logs wiki-cluster  # Check error messages
```

### Port 8080 Already in Use

**Solution**: Use a different port mapping

```bash
docker run --privileged -p 9080:8080 --name wiki-cluster wiki-cluster
# Access via http://localhost:9080
```

### Services Not Accessible

**Cause**: Cluster still initializing
**Solution**: Wait 3-5 minutes for full startup

```bash
# Check pod status
docker exec wiki-cluster kubectl get pods -n default

# All pods should show STATUS: Running and READY: 1/1
```

### Slow Performance or OOM Errors

**Cause**: Insufficient resources
**Solution**: Increase Docker resource limits

- Docker Desktop → Settings → Resources
- Set at least 2 CPUs and 4GB RAM

### Database Connection Errors

**Check**:
1. PostgreSQL pod is running: `kubectl get pods | grep postgresql`
2. Database credentials in wiki-chart/values.yaml match fastapi.env settings
3. Service name matches: `wiki-chart-postgresql`

## Cleanup

### Stop and Remove Container

```bash
docker stop wiki-cluster
docker rm wiki-cluster
```

### Complete Cleanup

```bash
# Remove container
docker stop wiki-cluster 2>/dev/null || true
docker rm wiki-cluster 2>/dev/null || true

# Remove images
docker rmi wiki-cluster 2>/dev/null || true
docker rmi wiki-service:latest 2>/dev/null || true

# Clean build cache (optional)
docker builder prune -f
```

## Technical Details

### Database Configuration

- **Driver**: asyncpg (async PostgreSQL adapter)
- **Connection Pool**: 10 connections, max overflow 20
- **Health Checks**: Pre-ping enabled for connection validation
- **Migrations**: Auto-create tables on startup via SQLAlchemy

### Performance Characteristics

- **Startup Time**: 3-5 minutes for full cluster initialization
- **API Response**: <100ms for simple CRUD operations
- **Concurrent Requests**: Supports 100+ concurrent connections via connection pooling
- **Metrics Scrape**: Every 15 seconds

## License

This project is part of the ATBL01 assignment.
