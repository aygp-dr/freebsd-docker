#!/bin/sh
# Quick setup script for Docker Hub credentials
# Helps users configure GitHub Actions secrets

set -e

echo "FreeBSD Docker - Docker Hub Setup"
echo "================================="
echo ""
echo "This script helps you set up Docker Hub credentials for GitHub Actions."
echo ""

# Check if gh CLI is installed
if ! command -v gh >/dev/null 2>&1; then
    echo "Error: GitHub CLI (gh) is not installed"
    echo ""
    echo "Install it:"
    echo "  FreeBSD: pkg install gh"
    echo "  Linux:   See https://github.com/cli/cli#installation"
    echo "  macOS:   brew install gh"
    echo ""
    echo "Or manually add secrets at:"
    echo "  https://github.com/aygp-dr/freebsd-docker/settings/secrets/actions"
    exit 1
fi

# Check if authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "Authenticating with GitHub..."
    gh auth login
fi

echo ""
echo "Enter your Docker Hub credentials:"
echo "(Get token at: https://hub.docker.com/settings/security)"
echo ""

# Get Docker Hub username
printf "Docker Hub Username: "
read -r DOCKER_USERNAME

# Get Docker Hub token
printf "Docker Hub Token: "
stty -echo
read -r DOCKER_TOKEN
stty echo
echo ""

# Confirm
echo ""
echo "Ready to add secrets to GitHub repository:"
echo "  Repository: aygp-dr/freebsd-docker"
echo "  Username: $DOCKER_USERNAME"
echo ""
printf "Continue? (y/n): "
read -r CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Cancelled"
    exit 0
fi

# Add secrets
echo ""
echo "Adding secrets..."

gh secret set DOCKER_HUB_USERNAME --body="$DOCKER_USERNAME" --repo=aygp-dr/freebsd-docker
gh secret set DOCKER_HUB_TOKEN --body="$DOCKER_TOKEN" --repo=aygp-dr/freebsd-docker

echo ""
echo "✓ Secrets added successfully!"
echo ""
echo "Next steps:"
echo "1. Create Docker Hub repository:"
echo "   https://hub.docker.com/repository/create"
echo "   Name: freebsd"
echo "   Namespace: $DOCKER_USERNAME"
echo ""
echo "2. Trigger build:"
echo "   gh workflow run build.yml --repo=aygp-dr/freebsd-docker"
echo ""
echo "3. Or push to trigger automatic build:"
echo "   git push origin main"
echo ""
echo "4. Check build status:"
echo "   https://github.com/aygp-dr/freebsd-docker/actions"
echo ""
echo "5. View images:"
echo "   https://hub.docker.com/r/$DOCKER_USERNAME/freebsd"