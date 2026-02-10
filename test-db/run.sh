#!/bin/bash

# Database Commander - PostgreSQL Test Database Runner

set -e

CONTAINER_NAME="dbc-test-postgres"
IMAGE_NAME="dbc-test-db"
DB_PORT="5432"
HOST_PORT="5433"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Database Commander - PostgreSQL Test Database${NC}"
echo "================================================"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

# Stop and remove existing container if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}Stopping existing container...${NC}"
    docker stop ${CONTAINER_NAME} > /dev/null 2>&1 || true
    docker rm ${CONTAINER_NAME} > /dev/null 2>&1 || true
fi

# Build the Docker image
echo -e "${GREEN}Building Docker image...${NC}"
docker build -t ${IMAGE_NAME} .

# Run the container
echo -e "${GREEN}Starting PostgreSQL container...${NC}"
docker run -d \
    --name ${CONTAINER_NAME} \
    -p ${HOST_PORT}:${DB_PORT} \
    ${IMAGE_NAME}

# Wait for PostgreSQL to be ready
echo -e "${YELLOW}Waiting for PostgreSQL to be ready...${NC}"
sleep 3

# Check if the container is running
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${GREEN}✓ PostgreSQL test database is running!${NC}"
    echo ""
    echo "Connection Details:"
    echo "  Host:     localhost"
    echo "  Port:     ${HOST_PORT}"
    echo "  Database: testdb"
    echo "  Username: dbcuser"
    echo "  Password: dbcpass"
    echo ""
    echo "Connection string:"
    echo "  postgresql://dbcuser:dbcpass@localhost:${HOST_PORT}/testdb"
    echo ""
    echo "Commands:"
    echo "  Stop:  ./stop.sh"
    echo "  Logs:  docker logs ${CONTAINER_NAME}"
    echo "  Shell: docker exec -it ${CONTAINER_NAME} psql -U dbcuser -d testdb"
else
    echo -e "${RED}✗ Failed to start PostgreSQL container${NC}"
    echo "Check logs with: docker logs ${CONTAINER_NAME}"
    exit 1
fi