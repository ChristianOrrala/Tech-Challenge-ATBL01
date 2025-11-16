# ATBL01 - Wikipedia-like API Service

Containerized Wikipedia-like API service with user/post management, metrics collection, and visualization. Complete Kubernetes cluster running in a single Docker container using k3d (Docker-in-Docker).

![Wiki Application](docs/img/wiki-app-01.jpg)

## Features

- FastAPI REST service for users and posts management
- PostgreSQL with async support and proper relationships
- Prometheus metrics collection with pre-configured Grafana dashboards
- Kubernetes deployment with NGINX Ingress Controller
- Self-contained k3d cluster in a single Docker container

## Architecture

![Wiki Service Architecture](docs/img/wiki-service.png)

### Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| API | FastAPI (Python 3.13) | REST endpoints |
| Database | PostgreSQL 15-alpine | Async persistence |
| Metrics | Prometheus | Time-series collection |
| Visualization | Grafana | Dashboards |
| Orchestration | k3d v5.7.4 | Container orchestration |
| Ingress | NGINX v1.11.2 | HTTP routing |

### Data Model

**Users**: `id`, `name`, `created_time`
**Posts**: `id`, `content`, `user_id` (FK), `created_time`
**Metrics**: `users_created_total`, `posts_created_total`

### Resource Allocation

Resources consume ~70% of container capacity, leaving headroom for cluster components:

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
|-----------|-------------|-----------|----------------|--------------|---------|
| FastAPI | 100m | 250m | 256Mi | 512Mi | - |
| PostgreSQL | 400m | 700m | 768Mi | 1280Mi | 2Gi |
| Prometheus | 250m | 450m | 600Mi | 1Gi | 2Gi |
| Grafana | 100m | 250m | 256Mi | 512Mi | 1Gi |
| **Total** | **~1.0 vCPU** | **~2.0 vCPU** | **~2GB** | **~4GB** | **~5GB** |

## Thoughts and Decisions

This section documents the key architectural decisions, trade-offs, and thought process behind the implementation of this project.

### Project Scope and Objectives

The project consists of two main parts: containerizing a FastAPI application and creating a Docker-in-Docker solution for easy deployment and testing. The original application had hardcoded connection strings pointing to a SQLite database, which were remapped to point to an external PostgreSQL service. The second part involved encapsulating a Kubernetes cluster using k3d inside a Docker container for simplified deployment and evaluation.

### Infrastructure and Ingress Controller

I replaced Traefik (the default ingress controller in k3d) with **NGINX Ingress Controller** to better reflect real-world production Kubernetes setups and simplify debugging during the evaluation. NGINX is more commonly used in production environments and provides more predictable behavior for troubleshooting.

### Application Modifications and Dependency Management

While adapting the wiki-service to work with environment variables for configuration, I noticed the project originally used `uv` for package installation and also contained a Poetry configuration file, likely from the original creator. I decided to use **Python and pip with a standard `requirements.txt`** file to make the setup more standard and avoid depending on additional tools that would complicate the build process. This decision prioritizes simplicity and widespread compatibility over specialized package management features.

I also included commands to build and run the container autonomously in a local environment, including a quick command to deploy a PostgreSQL database for testing purposes.

### Containerization Strategy

For the Dockerfiles, I paid special attention to creating **efficient, fast, and well-planned** builds that leverage Docker's layer caching. I carefully ordered the build steps to maximize cache utilization during iterative development. I did not find justification for using multi-stage builds in this particular use case, as the benefits wouldn't outweigh the added complexity.

The main Dockerfile and `entrypoint.sh` were designed with different priorities: the Dockerfile remains simple and fast, copying the wiki-service files for subsequent image building and wiki-chart files for chart generation. The `entrypoint.sh` is designed to provide visual feedback with colors and verbose output that clearly indicates deployment progress and provides a summary with useful endpoint access information.

For the sake of simplicity in this test environment, I decided to include the wiki-service image build phase in the `entrypoint.sh` rather than using a local image registry to isolate the build step. While a registry would be more production-like, it felt like an excessive endorsement for this scope.

### Helm Chart Architecture

I adopted an **umbrella chart methodology** with all components as dependencies. The templates are designed so that everything depends on `values.yaml` for configuration, centralizing parameterization. This approach allows you to swap the `values.yaml` file and adapt the environment to different contexts without modifying templates.

For Grafana specifically, I used a **sidecar pattern with a ConfigMap containing a JSON file** to pre-configure dashboards, ensuring the dashboard is immediately available upon deployment rather than requiring manual import.

### Endpoint Exposure Strategy

After analyzing the `test_api.sh` file included in the project, I noticed it tested endpoints including `/user` and `/metrics`. While the requirements mentioned some endpoints as examples, they also stated "expose all the required endpoints from Part 1." I decided to include all necessary endpoints, not just the examples. It's worth noting that endpoints like `/metrics` are typically for internal use within the cluster and might not be exposed outside in production environments, but I included them for testing completeness.

### Resource Management

I established resource limits and requests for deployments to consume approximately **70% of the total resources** of the main container, leaving resources available for cluster components and the host itself. This prevents resource exhaustion and potential cluster failure, which is critical in a single-node configuration handling all resources.

### Namespace Strategy

All resources for this practice were created in the **default namespace**. Normally, I always create a specific namespace for each project, but for this technical test, I considered the default namespace more appropriate given the self-contained and temporary nature of the environment.

### Persistence and Storage

For data persistence, I decided to rely on **k3d's default local-path provisioner** using Persistent Volume Claims (PVCs) for each deployment. This allows pods to be deleted without losing data. However, this data is ephemeral outside the main container as no external storage is configured, a reasonable trade-off for a test environment.

### Version Management and Dependencies

Since no specific versions for dependencies were specified, I decided to use the **latest charts available**. Given this is a test environment rather than a production system, I didn't prioritize Long-Term Support (LTS) versions.

### Wait Strategies

There's a mix of native `wait` commands and a custom `wait_for` function to give services time to become available. This hybrid approach balances between Kubernetes-native readiness checks and explicit timing controls for services that might not expose proper health endpoints.

### Security Considerations and Trade-offs

Being a self-contained environment for a test challenge, I decided to keep **passwords and credentials hardcoded** in variable files, which is not recommended for production environments where we would use Kubernetes Secrets or external secret management solutions.

The scope of this project does not address **High Availability, network policies, or Role-Based Access Control (RBAC)**. I understand this lack of security measures is expected in a testing environment for practice purposes, but these would be primary considerations in more complete or production-ready deployments.

I also did not include special configurations for **TLS certificates or least-privilege security practices** due to the convenience and time constraints of this test project. In production, all ingress traffic would use TLS, service accounts would have minimal required permissions, and network policies would restrict pod-to-pod communication.

### Image Tagging and Registry

Being a test environment, I used **simple tagging mechanisms** (e.g., `latest`). In a production environment, I would be mindful about versioning and use semantic versioning with immutable tags (e.g., `v1.2.3`, git commit SHAs) to ensure reproducibility and enable rollbacks.

### Limitations and Future Considerations

The current implementation has several known limitations that are acceptable for this test environment:

- **Single-node cluster**: No high availability or redundancy
- **Ephemeral storage**: Data persists only within the container lifecycle
- **No network segmentation**: All services can communicate freely
- **Simplified security model**: Hardcoded credentials and no RBAC
- **No TLS/encryption**: All traffic is unencrypted HTTP
- **Latest versions**: Dependencies are not pinned to specific versions

In a production scenario, these would need to be addressed with multi-node clusters, external persistent storage, network policies, proper secret management, certificate management, and strict version control.

## Quick Start

### Prerequisites

- Docker 20.10+
- 2 CPUs, 4GB RAM minimum
- 5GB disk space
- Port 8080 available

### Build & Run

```bash
docker build -t wiki-cluster .
docker run --privileged -p 8080:8080 --name wiki-cluster wiki-cluster
docker logs -f wiki-cluster
```

Startup takes 3-5 minutes. Wait for "Wiki Cluster is ready!" message.

### Endpoints

| Endpoint | URL | Description |
|----------|-----|-------------|
| Users API | http://localhost:8080/users/ | Create/list users |
| User Details | http://localhost:8080/user/{id} | Get user by ID |
| Posts API | http://localhost:8080/posts/ | Create/list posts |
| Post Details | http://localhost:8080/posts/{id} | Get post by ID |
| API Docs | http://localhost:8080/docs | Swagger UI |
| Metrics | http://localhost:8080/metrics | Prometheus endpoint |
| Grafana | http://localhost:8080/grafana/ | Dashboards (admin/admin) |
| Creation Dashboard | http://localhost:8080/grafana/d/creation-dashboard-678/creation | Pre-configured dashboard |

## Testing & Load Generation

### Automated Testing

The `wiki-service/test_api.sh` script was used throughout development to:

- **Validate cluster functionality** after each deployment
- **Generate traffic** for Grafana dashboard visualization
- **Stress test resource allocation** to verify the 70% limit threshold

**Usage:**

```bash
# From host (cluster must be running)
docker exec wiki-cluster bash -c "cd /wiki-service && ./test_api.sh"

# Or copy script to host and run
chmod +x wiki-service/test_api.sh
./wiki-service/test_api.sh
```

**Test Coverage:**

- Creates 3 users and 3 posts
- Tests GET endpoints for users/posts by ID
- Validates error handling (404 responses)
- Verifies Prometheus metrics collection
- Increments counters for dashboard visualization

**Continuous Load:**

```bash
# Generate continuous traffic for dashboard testing
while true; do
  curl -X POST http://localhost:8080/users/ \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"User-$(date +%s)\"}"
  curl -X POST http://localhost:8080/posts/ \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": 1, \"content\": \"Post at $(date)\"}"
  sleep 2
done
```

This generates steady creation rate metrics visible in the Grafana dashboard at http://localhost:8080/grafana/d/creation-dashboard-678/creation.

### Resource Validation

The 70% resource allocation was validated by:

1. Running test_api.sh repeatedly under load
2. Monitoring pod resource usage: `kubectl top pods`
3. Ensuring no OOM kills or CPU throttling
4. Verifying cluster stability over extended periods

## API Examples

### Create User

```bash
curl -X POST http://localhost:8080/users/ \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe"}'
```

### Create Post

```bash
curl -X POST http://localhost:8080/posts/ \
  -H "Content-Type: application/json" \
  -d '{"content": "My first post", "user_id": 1}'
```

### View Metrics

```bash
curl http://localhost:8080/metrics | grep created_total
```

## Local Development

Run wiki-service standalone without k3d:

```bash
docker network create wiki-net

docker run -d --name postgres --network wiki-net \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=wiki -p 5432:5432 postgres:15-alpine

docker build -t wiki-service wiki-service/

docker run -d --name wiki-service --network wiki-net -p 8000:8000 \
  -e DB_USER=postgres -e DB_PASSWORD=postgres \
  -e DB_HOST=postgres -e DB_PORT=5432 -e DB_NAME=wiki \
  wiki-service
```

Access at http://localhost:8000/docs

## Project Structure

```
/
├── Dockerfile                  # k3d cluster container
├── entrypoint.sh              # Cluster initialization
├── wiki-service/              # FastAPI application
│   ├── Dockerfile
│   ├── test_api.sh           # Automated test suite
│   └── app/
│       ├── main.py          # API endpoints
│       ├── models.py        # SQLAlchemy models
│       ├── schemas.py       # Pydantic schemas
│       ├── database.py      # PostgreSQL config
│       └── metrics.py       # Prometheus metrics
└── wiki-chart/               # Helm umbrella chart
    ├── Chart.yaml           # Dependencies manifest
    ├── values.yaml          # Centralized configuration
    ├── templates/           # K8s manifests
    └── dashboards/          # Grafana JSON
```

## Cluster Inspection

```bash
docker exec -it wiki-cluster bash

kubectl get pods,svc,ingress
kubectl logs <pod-name>
kubectl top pods  # Resource usage
```

## Troubleshooting

**Container exits immediately**: Missing `--privileged` flag
**Port 8080 in use**: Change port mapping `-p 9080:8080`
**Services not accessible**: Wait 3-5 minutes for initialization
**OOM/slow performance**: Increase Docker resources to 4GB+ RAM
**Database errors**: Verify PostgreSQL pod is running

## Cleanup

```bash
docker stop wiki-cluster && docker rm wiki-cluster
docker rmi wiki-cluster wiki-service:latest
```

## Technical Notes

- **Helm**: Umbrella chart with Bitnami dependencies
- **Storage**: k3d local-path provisioner with PVCs (ephemeral outside container)
- **Security**: Hardcoded credentials for test environment only
- **Ingress**: NGINX replaces default Traefik for production similarity
- **Versions**: Latest charts used (test environment, not LTS)
- **Namespace**: Default namespace for simplicity
