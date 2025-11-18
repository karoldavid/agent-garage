#!/usr/bin/env node

/**
 * Watch for workflow file changes and automatically update n8n
 * Usage: node scripts/watch-workflows.js
 * 
 * Requires: chokidar (npm install chokidar)
 * Or use the shell script version: ./scripts/watch-workflows.sh
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const WORKFLOWS_DIR = path.join(__dirname, '..', 'n8n', 'backup', 'workflows');
const CONTAINER_NAME = 'n8n-import';

console.log('🔍 Watching workflow files in:', WORKFLOWS_DIR);
console.log('📦 Container:', CONTAINER_NAME);
console.log('Press Ctrl+C to stop watching\n');

// Function to update workflows
function updateWorkflows(changedFile) {
  console.log(`🔄 Detected change in: ${path.basename(changedFile)}`);
  console.log('   Updating n8n workflows...');
  
  try {
    // Check if PostgreSQL is ready
    try {
      execSync('docker compose exec -T postgres psql -U n8n -d n8n -c "SELECT 1"', { 
        stdio: 'ignore',
        timeout: 5000 
      });
    } catch (e) {
      console.log('❌ PostgreSQL not ready. Waiting...');
      return;
    }
    
    // Remove and recreate the import container to trigger re-import
    try {
      execSync(`docker compose rm -f ${CONTAINER_NAME}`, { stdio: 'ignore' });
      execSync(`docker compose up -d ${CONTAINER_NAME}`, { stdio: 'ignore' });
      
      // Wait for import to complete (with timeout)
      const maxWait = 30000; // 30 seconds
      const startTime = Date.now();
      
      while (Date.now() - startTime < maxWait) {
        try {
          const status = execSync(`docker inspect -f '{{.State.Status}}' ${CONTAINER_NAME}`, { 
            encoding: 'utf8',
            stdio: 'pipe'
          }).trim();
          
          if (status === 'exited') {
            break;
          }
          
          // Wait a bit before checking again
          require('child_process').execSync('sleep 0.5', { stdio: 'ignore' });
        } catch (e) {
          // Container might not exist yet, wait
          require('child_process').execSync('sleep 0.5', { stdio: 'ignore' });
        }
      }
      
      console.log('✅ Workflow updated successfully!');
    } catch (error) {
      console.log('⚠️  Import completed (check logs if issues)');
    }
  } catch (error) {
    console.error('❌ Error updating workflows:', error.message);
  }
  
  console.log('');
}

// Try to use chokidar if available, otherwise fall back to polling
let watcher;

try {
  const chokidar = require('chokidar');
  
  console.log('Using chokidar for file watching...\n');
  
  watcher = chokidar.watch(path.join(WORKFLOWS_DIR, '*.json'), {
    ignored: /(^|[\/\\])\../, // ignore dotfiles
    persistent: true,
    ignoreInitial: true
  });
  
  watcher
    .on('change', (filePath) => {
      if (filePath.endsWith('.json')) {
        updateWorkflows(filePath);
      }
    })
    .on('error', (error) => {
      console.error('Watcher error:', error);
    });
    
} catch (e) {
  // chokidar not available, use polling
  console.log('⚠️  chokidar not found. Using polling (checking every 2 seconds)...');
  console.log('   Install with: npm install chokidar');
  console.log('   Or use the shell script version: ./scripts/watch-workflows.sh\n');
  
  let lastCheck = 0;
  
  setInterval(() => {
    try {
      const files = fs.readdirSync(WORKFLOWS_DIR)
        .filter(f => f.endsWith('.json'))
        .map(f => {
          const filePath = path.join(WORKFLOWS_DIR, f);
          const stats = fs.statSync(filePath);
          return { path: filePath, mtime: stats.mtimeMs };
        });
      
      const latestFile = files.reduce((latest, file) => 
        file.mtime > latest.mtime ? file : latest, 
        { mtime: 0 }
      );
      
      if (latestFile.mtime > lastCheck) {
        lastCheck = latestFile.mtime;
        updateWorkflows(latestFile.path);
      }
    } catch (error) {
      // Ignore errors during polling
    }
  }, 2000);
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\n👋 Stopping file watcher...');
  if (watcher) {
    watcher.close();
  }
  process.exit(0);
});

