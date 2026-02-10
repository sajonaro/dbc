# Database Commander - PostgreSQL Test Database

This directory contains a PostgreSQL test database setup for developing and testing the Database Commander application.

## Quick Start

### Start the database:
```bash
cd test-db
./run.sh
```

### Stop the database:
```bash
./stop.sh
```

## Connection Details

Once running, you can connect to the test database with:

- **Host:** localhost
- **Port:** 5432
- **Database:** testdb
- **Username:** dbcuser
- **Password:** dbcpass

**Connection String:**
```
postgresql://dbcuser:dbcpass@localhost:5432/testdb
```

## Test Data

The database includes sample data for testing:

### Public Schema
- **users** - Sample user accounts (4 users)
- **posts** - Blog posts (4 posts)
- **comments** - Post comments (6 comments)
- **user_post_summary** - View aggregating user post statistics

### Analytics Schema
- **page_views** - Sample page view tracking data

## Using the Test Database

### Access psql shell:
```bash
docker exec -it dbc-test-postgres psql -U dbcuser -d testdb
```

### View logs:
```bash
docker logs dbc-test-postgres
```

### List tables:
```sql
\dt
\dt analytics.*
```

### Sample queries to test:
```sql
-- View all users
SELECT * FROM users;

-- Posts with author info
SELECT p.title, u.username, p.view_count 
FROM posts p 
JOIN users u ON p.user_id = u.id;

-- User post summary
SELECT * FROM user_post_summary;

-- Analytics data
SELECT * FROM analytics.page_views;
```

## Requirements

- Docker installed and running
- Port 5432 available (or modify HOST_PORT in run.sh)

## Troubleshooting

If the container fails to start:
1. Check Docker is running: `docker info`
2. Check port availability: `lsof -i :5432`
3. View container logs: `docker logs dbc-test-postgres`
4. Remove stuck container: `docker rm -f dbc-test-postgres`

## Files

- `Dockerfile` - PostgreSQL container definition
- `init.sql` - Database initialization with test data
- `run.sh` - Start the test database
- `stop.sh` - Stop and remove the test database