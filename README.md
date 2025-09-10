# FreeBSD Docker Image Repository

A Docker-based solution for running FreeBSD in containers using QEMU virtualization.

## Overview

This repository provides a complete setup for running FreeBSD virtual machines inside Docker containers using QEMU. The architecture allows FreeBSD to run on any Docker-compatible host system by leveraging hardware virtualization.

## Features

- FreeBSD 14.0-RELEASE support
- QEMU-based virtualization
- Automated installation and configuration
- Docker Compose orchestration
- SSH access to FreeBSD instances
- Persistent storage support
- Network bridge configuration

## Quick Start

```bash
# Build the Docker image
docker build -t freebsd-docker .

# Run with Docker Compose
docker-compose up -d

# Access the FreeBSD instance
ssh -p 2222 root@localhost
```

## Architecture

The system uses a three-layer architecture:
1. **Host System**: Runs Docker Engine
2. **Docker Container**: Alpine Linux with QEMU
3. **FreeBSD VM**: Full FreeBSD system running inside QEMU

## Requirements

- Docker Engine 20.10+
- Docker Compose 2.0+
- 4GB RAM minimum
- 20GB free disk space

## Documentation

See `setup.org` for complete implementation details and configuration options.

## License

BSD 3-Clause License