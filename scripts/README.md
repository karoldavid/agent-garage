# Workflow Auto-Update Scripts

These scripts automatically update n8n workflows when you modify JSON files in `n8n/backup/workflows/`.

## Quick Start

### Option 1: Shell Script (Recommended - No dependencies)

```bash
./scripts/watch-workflows.sh
```

**Requirements:**
- macOS: `brew install fswatch` (optional, for better performance)
- Linux: `apt-get install inotify-tools` (optional, for better performance)
- Works without these tools using polling (less efficient)

### Option 2: Node.js Script (Faster, requires npm)

```bash
# Install dependency (one-time)
npm install chokidar

# Run the watcher
node scripts/watch-workflows.js
```

## How It Works

1. **Watches** for changes to `.json` files in `n8n/backup/workflows/`
2. **Detects** when you save a workflow file
3. **Automatically** re-runs the n8n import container
4. **Updates** the workflow in your running n8n instance

## Usage

1. Start your n8n instance:
   ```bash
   docker compose up -d
   ```

2. In a separate terminal, start the watcher:
   ```bash
   ./scripts/watch-workflows.sh
   ```

3. Edit any workflow JSON file in `n8n/backup/workflows/`

4. Save the file - the watcher will automatically update n8n!

## Example Output

```
🔍 Watching workflow files in: n8n/backup/workflows
📦 Container: n8n-import
Press Ctrl+C to stop watching

🔄 Detected change in: 4_Log_Error_Pattern_Detector_v2.json
   Updating n8n workflows...
   Waiting for import to complete...
✅ Workflow updated successfully!
```

## Troubleshooting

### Script doesn't detect changes
- Make sure you're saving the file (not just editing)
- Check that the file path is correct
- Try restarting the watcher

### Import fails
- Check that Docker containers are running: `docker compose ps`
- Check n8n-import logs: `docker logs n8n-import`
- Verify PostgreSQL is ready: `docker compose exec postgres pg_isready`

### Performance issues
- Install `fswatch` (macOS) or `inotify-tools` (Linux) for better performance
- Or use the Node.js version with `chokidar`

## Manual Update (Alternative)

If you prefer to update manually:

```bash
# Re-import all workflows
docker compose rm -f n8n-import
docker compose up -d n8n-import

# Or import a specific workflow via n8n UI:
# 1. Open http://localhost:5678
# 2. Workflows → Import from File
# 3. Select your workflow JSON file
```

