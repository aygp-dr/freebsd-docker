#!/bin/bash
set -e

echo "⚡ RAPID DEPLOYMENT SCRIPT"
echo "=========================="

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

echo "1️⃣ Testing Docker Hub login..."
echo "$DOCKERHUB_TOKEN" | docker login docker.io -u "$DOCKERHUB_USERNAME" --password-stdin || exit 1

echo "2️⃣ Pushing to GitHub Secrets..."
gh secret set DOCKERHUB_USERNAME --body="$DOCKERHUB_USERNAME" && \
gh secret set DOCKERHUB_TOKEN --body="$DOCKERHUB_TOKEN"

echo "3️⃣ Triggering workflow..."
gh workflow run docker-publish.yml

echo "4️⃣ Logging out of Docker Hub..."
docker logout docker.io

echo "5️⃣ Clearing local token..."
echo "DOCKERHUB_USERNAME=aygpdr" > .env
echo "DOCKERHUB_TOKEN=CLEARED" >> .env

echo ""
echo "✅ DEPLOYMENT COMPLETE - TOKEN CLEARED FROM LOCAL"
echo ""
echo "📊 Watch the build with:"
echo "gh run watch"
echo ""
echo "🔄 After success, IMMEDIATELY rotate your token at:"
echo "https://app.docker.com/settings/personal-access-tokens"