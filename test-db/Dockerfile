FROM postgres:16-alpine

# Set environment variables for the test database
ENV POSTGRES_USER=dbcuser
ENV POSTGRES_PASSWORD=dbcpass
ENV POSTGRES_DB=testdb

# Copy initialization script
COPY init.sql /docker-entrypoint-initdb.d/

# Expose PostgreSQL port
EXPOSE 5432