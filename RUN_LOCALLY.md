# Running FreeBSD Docker Locally

## Option 1: Use Pre-built Image (Once Available)

Once the CI builds complete, images will be available at:
```bash
# From GitHub Container Registry (no auth needed for public images)
docker pull ghcr.io/aygp-dr/freebsd:14.3-RELEASE
docker run -it --rm --privileged ghcr.io/aygp-dr/freebsd:14.3-RELEASE

# With SSH access
docker run -d --privileged -p 2222:22 ghcr.io/aygp-dr/freebsd:14.3-RELEASE
ssh -p 2222 root@localhost  # password: freebsd
```

## Option 2: Build Locally (Linux/Mac with Docker)

Since you're on FreeBSD, you'll need a Linux VM or use a cloud service:

### On a Linux System:
```bash
# Clone the repository
git clone https://github.com/aygp-dr/freebsd-docker
cd freebsd-docker

# Build the image
docker build -t freebsd-local:14.0 .

# Run the container
docker run -it --rm --privileged freebsd-local:14.0

# Or with docker-compose
docker-compose up -d
```

## Option 3: Use GitHub Codespaces

1. Go to https://github.com/aygp-dr/freebsd-docker
2. Click "Code" → "Codespaces" → "Create codespace"
3. In the terminal:
```bash
docker build -t freebsd:test .
docker run -it --rm --privileged freebsd:test
```

## Option 4: Use a Cloud Provider

### DigitalOcean Docker Droplet:
```bash
# Create a Docker droplet, SSH in, then:
git clone https://github.com/aygp-dr/freebsd-docker
cd freebsd-docker
docker-compose up -d
```

### AWS EC2:
```bash
# Launch Ubuntu instance with Docker, then same as above
```

## Running on FreeBSD (Your Current System)

FreeBSD doesn't run Docker natively, but you have options:

### Option A: Use bhyve with a Linux VM
```bash
# Install bhyve
pkg install vm-bhyve

# Create Linux VM with Docker
vm create -t linux-docker ubuntu
vm install ubuntu ubuntu-22.04-server-amd64.iso
vm start ubuntu

# SSH into the VM and run Docker there
```

### Option B: Use jail with Linux compatibility
```bash
# This is complex and not recommended
# Better to use a Linux VM
```

### Option C: Wait for CI/CD
The GitHub Actions will build and publish images automatically. Once complete:
```bash
# On any Linux system with Docker:
docker pull ghcr.io/aygp-dr/freebsd:14.3-RELEASE
```

## Quick Test Commands

Once you have the container running:
```bash
# Connect via SSH (from host)
docker exec -it freebsd-vm ssh

# Run jail commands
docker exec freebsd-vm jail list

# Run ZFS commands  
docker exec freebsd-vm zfs status

# Access console
docker exec -it freebsd-vm /bin/sh
```

## Checking Build Status

```bash
# Check if images are available yet
gh run list --workflow=ci.yml --repo=aygp-dr/freebsd-docker

# View packages (once published)
gh api "orgs/aygp-dr/packages?package_type=container"
```

## Notes for FreeBSD Users

Since you're on FreeBSD, the easiest options are:
1. Wait for the CI to complete and use the published images on a Linux system
2. Use a cloud provider with Docker pre-installed
3. Set up a local Linux VM with bhyve for Docker