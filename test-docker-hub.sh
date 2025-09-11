#!/bin/bash
set -e

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "❌ .env file not found!"
    echo "Create .env with:"
    echo "DOCKERHUB_USERNAME=aygpdr"
    echo "DOCKERHUB_TOKEN=your-token-here"
    exit 1
fi

# Check if variables are set
if [ -z "$DOCKERHUB_USERNAME" ] || [ -z "$DOCKERHUB_TOKEN" ]; then
    echo "❌ Missing DOCKERHUB_USERNAME or DOCKERHUB_TOKEN in .env"
    exit 1
fi

echo "🔐 Testing Docker Hub authentication..."
echo "Username: $DOCKERHUB_USERNAME"

# Test login
echo "$DOCKERHUB_TOKEN" | docker login docker.io -u "$DOCKERHUB_USERNAME" --password-stdin

if [ $? -eq 0 ]; then
    echo "✅ Docker Hub login successful!"
    
    # Test pulling (should work even without login, but confirms connectivity)
    echo "🔍 Testing Docker pull..."
    docker pull alpine:latest > /dev/null 2>&1
    
    # Show what we would push to
    echo "📦 Would push to: docker.io/${DOCKERHUB_USERNAME}/freebsd"
    
    # Logout for security
    docker logout docker.io
    echo "🔒 Logged out from Docker Hub"
    
    echo ""
    echo "✅ Ready to push secrets to GitHub!"
    echo "Run this command to add secrets:"
    echo ""
    echo "gh secret set DOCKERHUB_USERNAME --body=\"$DOCKERHUB_USERNAME\""
    echo "gh secret set DOCKERHUB_TOKEN --body=\"$DOCKERHUB_TOKEN\""
    echo ""
    echo "Or do it in one line:"
    echo "gh secret set DOCKERHUB_USERNAME --body=\"$DOCKERHUB_USERNAME\" && gh secret set DOCKERHUB_TOKEN --body=\"$DOCKERHUB_TOKEN\""
else
    echo "❌ Docker Hub login failed!"
    exit 1
fi