#!/bin/bash

# Watch for workflow file changes and automatically update n8n
# Usage: ./scripts/watch-workflows.sh

set +e  # Don't exit on errors, allow script to continue

WORKFLOWS_DIR="n8n/backup/workflows"
CONTAINER_NAME="n8n-import"

echo "🔍 Watching workflow files in: $WORKFLOWS_DIR"
echo "📦 Container: $CONTAINER_NAME"
echo "Press Ctrl+C to stop watching"
echo ""

# Function to update workflows
update_workflows() {
    local file="$1"
    echo "🔄 Detected change in: $file"
    echo "   Updating n8n workflows..."
    
    # Remove and recreate the import container to trigger re-import
    docker compose rm -f "$CONTAINER_NAME" > /dev/null 2>&1
    docker compose up -d "$CONTAINER_NAME" > /dev/null 2>&1
    
    # Wait for import to complete
    echo "   Waiting for import to complete..."
    sleep 2  # Give container time to start
    timeout=30
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        status=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "notfound")
        if [ "$status" = "exited" ]; then
            exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$CONTAINER_NAME" 2>/dev/null || echo "1")
            if [ "$exit_code" = "0" ]; then
                echo "✅ Workflow updated successfully!"
            else
                echo "⚠️  Import completed with exit code $exit_code (check logs if issues)"
            fi
            break
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    if [ $elapsed -ge $timeout ]; then
        echo "⚠️  Timeout waiting for import (container may still be running)"
    fi
    echo ""
}

# Check if fswatch is installed (macOS/Linux)
if command -v fswatch &> /dev/null; then
    echo "Using fswatch..."
    fswatch -r -e ".*" -i "\\.json$" "$WORKFLOWS_DIR" | while read changed_file; do
        if [ -n "$changed_file" ] && [[ "$changed_file" == *.json ]]; then
            # Small delay to ensure file write is complete
            sleep 0.5
            update_workflows "$changed_file"
        fi
    done
# Check if inotifywait is installed (Linux)
elif command -v inotifywait &> /dev/null; then
    echo "Using inotifywait..."
    inotifywait -m -r -e modify,create,delete --format '%w%f' "$WORKFLOWS_DIR" | while read file; do
        if [[ "$file" == *.json ]]; then
            update_workflows "$file"
        fi
    done
# Fallback: use polling (works everywhere but less efficient)
else
    echo "⚠️  fswatch/inotifywait not found. Using polling (checking every 2 seconds)..."
    echo "   Install fswatch (macOS: brew install fswatch) or inotifywait (Linux: apt-get install inotify-tools) for better performance"
    echo ""
    
    last_check=$(find "$WORKFLOWS_DIR" -name "*.json" -type f -exec stat -f "%m" {} \; 2>/dev/null | sort -n | tail -1 || echo "0")
    
    while true; do
        sleep 2
        current_check=$(find "$WORKFLOWS_DIR" -name "*.json" -type f -exec stat -f "%m" {} \; 2>/dev/null | sort -n | tail -1 || echo "0")
        
        if [ "$current_check" != "$last_check" ] && [ "$current_check" != "0" ]; then
            changed_file=$(find "$WORKFLOWS_DIR" -name "*.json" -type f -newermt "@$last_check" 2>/dev/null | head -1 || echo "")
            if [ -n "$changed_file" ]; then
                update_workflows "$changed_file"
                last_check="$current_check"
            fi
        fi
    done
fi

