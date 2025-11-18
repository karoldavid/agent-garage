#!/bin/bash

# Quick test script to manually trigger workflow update
# Usage: ./scripts/test-update.sh

CONTAINER_NAME="n8n-import"

echo "🧪 Testing workflow update..."
echo ""

# Remove and recreate import container
echo "1. Re-running n8n-import container..."
docker compose rm -f "$CONTAINER_NAME" > /dev/null 2>&1
docker compose up -d "$CONTAINER_NAME" > /dev/null 2>&1

# Wait for completion
echo "2. Waiting for import to complete..."
sleep 2
timeout=30
elapsed=0
while [ $elapsed -lt $timeout ]; do
    status=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "notfound")
    if [ "$status" = "exited" ]; then
        exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$CONTAINER_NAME" 2>/dev/null || echo "1")
        if [ "$exit_code" = "0" ]; then
            echo "   ✅ Import completed successfully!"
            echo ""
            echo "✅ Test passed! Workflows should be updated in n8n."
            exit 0
        else
            echo "   ⚠️  Import completed with exit code $exit_code"
            docker logs "$CONTAINER_NAME" --tail 10
            exit 1
        fi
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

echo "   ⚠️  Timeout waiting for import"
exit 1

