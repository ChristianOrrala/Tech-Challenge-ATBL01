# ATBL01

```bash
# wiki-service Deployment Instructions for local Docker Environment

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
docker build -t wiki-service wiki-service/Dockerfile

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
docker stop wiki-app || true
docker stop postgres || true

# Remove containers
docker rm wiki-app || true
docker rm postgres || true

# Remove image
docker rmi wiki-service || true

# Remove network
docker network rm wiki-net || true

```