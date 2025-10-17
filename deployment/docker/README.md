# Docker Deployment Guide

This directory contains Docker configuration files for the Workflow Management System.

## Files Overview

### Core Docker Files

- **docker-compose.yml** - Main Docker Compose configuration with all services
- **docker-compose.prod.yml** - Production-specific overrides and additional services
- **Dockerfile.backend** - Python FastAPI backend with Rust components
- **Dockerfile.frontend** - React frontend with Nginx
- **Dockerfile.frontend-dev** - Development frontend with hot reload
- **Dockerfile.fileserver** - Node.js file server
- **nginx.conf** - Nginx configuration for development
- **nginx.prod.conf** - Nginx configuration for production
- **backup-script.sh** - Automated database backup script

## Quick Start

### 1. Setup Environment

```bash
cd /path/to/workflow-management
cp .env.example .env
# Edit .env with your configuration
```

### 2. Development Mode

```bash
# Using docker-compose directly
docker-compose -f deployment/docker/docker-compose.yml --profile development up -d

# Or using Makefile
make -f Makefile.docker dev
```

### 3. Production Mode

```bash
# Using docker-compose directly
docker-compose -f deployment/docker/docker-compose.yml \
               -f deployment/docker/docker-compose.prod.yml \
               --profile production up -d

# Or using Makefile
make -f Makefile.docker prod
```

## Service Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Nginx (Production)                    │
│              (Reverse Proxy & Load Balancer)             │
└──────────────┬──────────────┬──────────────┬─────────────┘
               │              │              │
        ┌──────▼──────┐ ┌────▼─────┐ ┌─────▼──────┐
        │  Frontend   │ │ Backend  │ │ File Server│
        │  (React)    │ │(FastAPI) │ │(Node.js)   │
        └──────┬──────┘ └────┬─────┘ └─────┬──────┘
               │             │             │
        ┌──────▼─────────────▼─────────────▼──────┐
        │         PostgreSQL Database              │
        │         Redis Cache                      │
        └─────────────────────────────────────────┘
```

## Environment Variables

Key environment variables in `.env`:

```
# Database
POSTGRES_DB=workflow_management
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_password

# Services
BACKEND_PORT=8000
FRONTEND_PORT=3000
FILE_SERVER_PORT=3001

# Environment
NODE_ENV=development
FLASK_ENV=development
```

See `.env.example` for complete list.

## Common Tasks

### View Logs

```bash
# All services
docker-compose -f deployment/docker/docker-compose.yml logs -f

# Specific service
docker-compose -f deployment/docker/docker-compose.yml logs -f backend
```

### Database Operations

```bash
# Connect to database
docker-compose -f deployment/docker/docker-compose.yml exec database psql -U postgres

# Backup database
docker-compose -f deployment/docker/docker-compose.yml exec database \
  pg_dump -U postgres workflow_management > backup.sql

# Restore database
docker-compose -f deployment/docker/docker-compose.yml exec -T database \
  psql -U postgres workflow_management < backup.sql
```

### Container Access

```bash
# Backend shell
docker-compose -f deployment/docker/docker-compose.yml exec backend bash

# Frontend shell
docker-compose -f deployment/docker/docker-compose.yml exec frontend-dev sh

# File server shell
docker-compose -f deployment/docker/docker-compose.yml exec file-server sh
```

## Production Deployment

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- SSL certificates (for HTTPS)
- Configured .env file with production values

### Steps

1. **Prepare SSL Certificates**

```bash
mkdir -p deployment/docker/ssl
# Copy your certificates to ssl/cert.pem and ssl/key.pem
```

2. **Configure Environment**

```bash
cp .env.example .env
# Edit .env with production values
```

3. **Build and Deploy**

```bash
docker-compose -f deployment/docker/docker-compose.yml \
               -f deployment/docker/docker-compose.prod.yml \
               build

docker-compose -f deployment/docker/docker-compose.yml \
               -f deployment/docker/docker-compose.prod.yml \
               --profile production up -d
```

4. **Verify Services**

```bash
docker-compose -f deployment/docker/docker-compose.yml \
               -f deployment/docker/docker-compose.prod.yml \
               ps
```

## Scaling

### Horizontal Scaling

For production, use Docker Swarm or Kubernetes:

```bash
# Docker Swarm
docker swarm init
docker stack deploy -c docker-compose.prod.yml workflow

# Kubernetes
kubectl apply -f deployment/kubernetes/
```

### Resource Limits

Edit `docker-compose.prod.yml` to adjust resource limits:

```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 2G
```

## Monitoring

### Health Checks

All services include health checks:

```bash
docker-compose -f deployment/docker/docker-compose.yml ps
```

### Logs

```bash
# Real-time logs
docker-compose -f deployment/docker/docker-compose.yml logs -f

# Last 100 lines
docker-compose -f deployment/docker/docker-compose.yml logs --tail=100
```

## Troubleshooting

### Services Won't Start

1. Check logs: `docker-compose logs -f`
2. Verify .env file
3. Check port availability
4. Ensure sufficient disk space

### Database Connection Issues

```bash
# Test connection
docker-compose exec backend python -c \
  "import psycopg2; psycopg2.connect('postgresql://postgres:password@database:5432/workflow_management')"
```

### Memory Issues

Increase Docker memory limit or adjust resource limits in docker-compose.

## Security Best Practices

1. **Change default passwords** in .env
2. **Use strong SECRET_KEY**
3. **Enable Redis password**
4. **Use HTTPS in production**
5. **Keep Docker images updated**
6. **Use secrets management** for sensitive data
7. **Enable firewall rules**
8. **Regular backups**

## Cleanup

```bash
# Stop services
docker-compose -f deployment/docker/docker-compose.yml down

# Remove volumes
docker-compose -f deployment/docker/docker-compose.yml down -v

# Remove all Docker resources
docker system prune -a
```

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Main DOCKER_GUIDE.md](../../DOCKER_GUIDE.md)
- [Project README](../../README.md)

