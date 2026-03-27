#!/bin/bash
set -e

# Setup data directory permissions
chown -R openclaw:openclaw /data
chmod 700 /data

# Setup linuxbrew
if [ ! -d /data/.linuxbrew ]; then
  cp -a /home/linuxbrew/.linuxbrew /data/.linuxbrew
fi
rm -rf /home/linuxbrew/.linuxbrew
ln -sfn /data/.linuxbrew /home/linuxbrew/.linuxbrew

# Configure git as openclaw user (NOT as root!)
gosu openclaw bash -c '
  echo "🤖 OpenClaw: Configuring self-modification capabilities..."
  
  # Trust the workspace directory
  git config --global --add safe.directory /data/workspace
  git config --global --add safe.directory /app
  
  # Configure git user
  git config --global user.email "openclaw@agent.ai"
  git config --global user.name "OpenClaw Agent"
  
  # Navigate to workspace
  cd /data/workspace || cd /app || true
  
  # Set remote with token
  if [ -n "$GITHUB_TOKEN" ] && [ -n "$GITHUB_REPO" ]; then
    git remote set-url origin "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" 2>/dev/null || \
    git remote add origin "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" 2>/dev/null || true
    echo "✅ Git configured! OpenClaw can now self-modify!"
  else
    echo "⚠️ GITHUB_TOKEN or GITHUB_REPO not set - skipping git setup"
  fi
  
  # Test git access
  if git status > /dev/null 2>&1; then
    echo "✅ Git access verified!"
  else
    echo "⚠️ Git not initialized yet (will be available after first workspace creation)"
  fi
'

# Start OpenClaw
echo "🚀 Starting OpenClaw server..."
exec gosu openclaw node src/server.js
