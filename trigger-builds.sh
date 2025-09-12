#!/bin/bash
set -e

echo "Triggering 5 builds to validate optimized pipeline..."

for i in {1..5}; do
    echo ""
    echo "Build iteration $i/5"
    
    # Make a small change to trigger build
    echo "# Build test $i - $(date)" >> README.md
    
    git add README.md
    git commit -m "test: validate build time optimization - iteration $i" --no-gpg-sign
    git push origin main
    
    echo "Triggered build $i, waiting 5 seconds..."
    sleep 5
    
    # Get the latest run ID
    RUN_ID=$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')
    echo "Build $i started with ID: $RUN_ID"
    
    # Monitor until completion
    echo "Monitoring build $i..."
    START=$(date +%s)
    
    while true; do
        STATUS=$(gh run view $RUN_ID --json status -q '.status')
        if [ "$STATUS" = "completed" ]; then
            END=$(date +%s)
            DURATION=$((END - START))
            CONCLUSION=$(gh run view $RUN_ID --json conclusion -q '.conclusion')
            echo "Build $i completed in ${DURATION}s with status: $CONCLUSION"
            break
        fi
        sleep 5
    done
done

echo ""
echo "All 5 validation builds completed!"
echo "Collecting timing statistics..."

gh run list --limit 5 --json displayTitle,status,conclusion,createdAt,updatedAt | jq -r '.[] | "\(.displayTitle): \(.conclusion) in \(.updatedAt)"'