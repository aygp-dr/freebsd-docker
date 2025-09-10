# Docker Hub Setup Guide

## Prerequisites

1. Docker Hub account at https://hub.docker.com
2. GitHub repository access with secrets permission

## Step 1: Create Docker Hub Access Token

1. Log in to Docker Hub: https://hub.docker.com
2. Go to Account Settings → Security
3. Click "New Access Token"
4. Give it a name: `github-actions-freebsd`
5. Set permissions: `Read, Write, Delete`
6. Copy the token (you won't see it again!)

## Step 2: Add GitHub Secrets

Go to your GitHub repository settings:
https://github.com/aygp-dr/freebsd-docker/settings/secrets/actions

Add these secrets:

### Required Secrets

| Secret Name | Value |
|------------|-------|
| `DOCKER_HUB_USERNAME` | Your Docker Hub username (e.g., `aygp-dr`) |
| `DOCKER_HUB_TOKEN` | The access token from Step 1 |

### How to Add Secrets

1. Click "New repository secret"
2. Name: `DOCKER_HUB_USERNAME`
3. Value: Your Docker Hub username
4. Click "Add secret"
5. Repeat for `DOCKER_HUB_TOKEN`

## Step 3: Create Docker Hub Repository

1. Go to https://hub.docker.com/repositories
2. Click "Create Repository"
3. Repository name: `freebsd`
4. Namespace: `aygp-dr` (your username)
5. Description: "FreeBSD virtual machines in Docker with QEMU, jails, and ZFS support"
6. Visibility: Public
7. Click "Create"

## Step 4: Trigger Build

The GitHub Actions workflow will automatically:
- Build on push to main branch
- Build multiple FreeBSD versions (14.0, 13.2)
- Push to Docker Hub with proper tags
- Support manual trigger via workflow_dispatch

### Manual Trigger

1. Go to Actions tab: https://github.com/aygp-dr/freebsd-docker/actions
2. Select "Build FreeBSD Docker Image"
3. Click "Run workflow"
4. Select branch and run

## Step 5: Verify

Check your images at:
https://hub.docker.com/r/aygp-dr/freebsd

Tags created:
- `aygp-dr/freebsd:14.1-RELEASE`
- `aygp-dr/freebsd:13.2-RELEASE`
- `aygp-dr/freebsd:latest` (points to 14.0)

## Local Testing (Linux/Mac only)

Since you're on FreeBSD, you can't build locally. Use GitHub Actions or a Linux VM:

```bash
# On a Linux system with Docker:
git clone https://github.com/aygp-dr/freebsd-docker
cd freebsd-docker
docker build -t aygp-dr/freebsd:test .
```

## Troubleshooting

### Authentication Failed

- Verify token has correct permissions
- Check secret names match exactly
- Regenerate token if needed

### Build Fails

- Check GitHub Actions logs
- Verify FreeBSD ISO URLs are valid
- Ensure sufficient runner resources

### Push Fails

- Verify repository exists on Docker Hub
- Check namespace matches username
- Ensure token has write permissions

## Security Notes

- Never commit tokens to repository
- Rotate tokens periodically
- Use least-privilege permissions
- Consider using OIDC for production

## Alternative: GitHub Container Registry

If Docker Hub isn't working, use GitHub's registry:

```yaml
# In workflow, replace docker.io with ghcr.io
- name: Log in to GitHub Container Registry
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

Images would be at: `ghcr.io/aygp-dr/freebsd`