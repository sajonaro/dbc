#!/bin/bash

# Database Commander - PostgreSQL Test Database Stopper

CONTAINER_NAME="dbc-test-postgres"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Stopping PostgreSQL test database...${NC}"

# Check if container exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    # Stop the container
    docker stop ${CONTAINER_NAME} > /dev/null 2>&1
    
    # Remove the container
    docker rm ${CONTAINER_NAME} > /dev/null 2>&1
    
    echo -e "${GREEN}✓ PostgreSQL test database stopped and removed${NC}"
else
    echo -e "${YELLOW}No running container found${NC}"
fi