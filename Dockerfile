# Multi-stage Dockerfile for Workflow Management System
# This Dockerfile builds the complete application stack:
# - Frontend (React + TypeScript + Vite)
# - Backend (Python FastAPI + Rust components)
# - File Server (Node.js + Express + Prisma)

# ============================================================================
# Stage 1: Rust Builder - Build device executor components
# ============================================================================
FROM rust:1.70-slim as rust-builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy Rust project files
COPY config/Cargo.toml config/Cargo.lock ./
COPY backend/device_executor/ ./device_executor/

# Build Rust components in release mode
RUN cargo build --release --manifest-path ./Cargo.toml

# ============================================================================
# Stage 2: Frontend Builder - Build React application
# ============================================================================
FROM node:18-alpine as frontend-builder

WORKDIR /build

# Copy package files
COPY package*.json ./
COPY tsconfig*.json ./
COPY vite.config.ts ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY src/ ./src/
COPY public/ ./public/
COPY index.html ./

# Build the application
RUN npm run build

# ============================================================================
# Stage 3: File Server Builder - Build Node.js file server
# ============================================================================
FROM node:18-alpine as fileserver-builder

WORKDIR /build

# Install build dependencies for native modules
RUN apk add --no-cache python3 make g++

# Copy server package files
COPY server/package*.json ./
COPY server/tsconfig.json ./

# Install dependencies
RUN npm ci --only=production

# Copy server source code
COPY server/src/ ./src/
COPY server/prisma/ ./prisma/

# Generate Prisma client
RUN npx prisma generate

# Build TypeScript
RUN npm run build

# ============================================================================
# Stage 4: Python Backend Builder - Prepare Python environment
# ============================================================================
FROM python:3.11-slim as backend-builder

WORKDIR /build

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy backend files
COPY backend/ ./backend/
COPY config/setup.py ./
COPY config/pytest.ini ./

# Create requirements.txt if it doesn't exist (for Docker build compatibility)
RUN if [ ! -f backend/requirements.txt ]; then \
    echo "fastapi>=0.104.0" > backend/requirements.txt && \
    echo "uvicorn>=0.24.0" >> backend/requirements.txt && \
    echo "pydantic>=2.5.0" >> backend/requirements.txt && \
    echo "aiohttp>=3.9.0" >> backend/requirements.txt && \
    echo "pyyaml>=6.0" >> backend/requirements.txt; \
    fi

# Install Python dependencies
RUN pip install --no-cache-dir -r backend/requirements.txt

# ============================================================================
# Stage 5: Final Runtime Image - Combine all components
# ============================================================================
FROM python:3.11-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    postgresql-client \
    libpq5 \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Create app user for security
RUN useradd --create-home --shell /bin/bash app

# ============================================================================
# Copy Frontend Build
# ============================================================================
COPY --from=frontend-builder /build/dist /app/frontend/dist

# ============================================================================
# Copy Backend Components
# ============================================================================
COPY --from=backend-builder /build/backend /app/backend
COPY --from=backend-builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=rust-builder /build/target/release /app/backend/device_executor/target/release

# ============================================================================
# Copy File Server Components
# ============================================================================
COPY --from=fileserver-builder /build/dist /app/fileserver/dist
COPY --from=fileserver-builder /build/node_modules /app/fileserver/node_modules
COPY --from=fileserver-builder /build/prisma /app/fileserver/prisma

# ============================================================================
# Setup Application Structure
# ============================================================================
RUN mkdir -p /app/logs /app/uploads && \
    chown -R app:app /app

# Copy configuration files
COPY deployment/docker/nginx.conf /app/nginx.conf
COPY .env.example /app/.env.example 2>/dev/null || true

# ============================================================================
# Health Check
# ============================================================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# ============================================================================
# Expose Ports
# ============================================================================
EXPOSE 3000 3001 8000 80

# ============================================================================
# Set User and Entry Point
# ============================================================================
USER app

# Default command - can be overridden
CMD ["python", "-m", "backend.main"]

