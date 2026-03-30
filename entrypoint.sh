#!/bin/bash
set -e

# Setup data directory permissions
chown -R openclaw:openclaw /data
chown -R sandbox:sandbox /data
chmod 700 /data

# Setup linuxbrew
if [ ! -d /data/.linuxbrew ]; then
  cp -a /home/linuxbrew/.linuxbrew /data/.linuxbrew
fi
rm -rf /home/linuxbrew/.linuxbrew
ln -sfn /data/.linuxbrew /home/linuxbrew/.linuxbrew
chown -R sandbox:sandbox /data/.linuxbrew

# Configure git as sandbox user
gosu sandbox bash -c '
  echo "🤖 NemoClaw: Configuring self-modification capabilities..."
  
  # Trust the workspace directory
  git config --global --add safe.directory /data/workspace
  git config --global --add safe.directory /app
  
  # Configure git user
  git config --global user.email "nemoclaw@agent.ai"
  git config --global user.name "NemoClaw Agent"
  
  # Navigate to workspace
  cd /data/workspace || cd /app || true
  
  # Set remote with token
  if [ -n "$GITHUB_TOKEN" ] && [ -n "$GITHUB_REPO" ]; then
    git remote set-url origin "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" 2>/dev/null || \
    git remote add origin "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" 2>/dev/null || true
    echo "✅ Git configured! NemoClaw can now self-modify!"
  else
    echo "⚠️ GITHUB_TOKEN or GITHUB_REPO not set - skipping git setup"
  fi
'

# Start NVIDIA OpenShell Gateway
echo "🛠️ Initializing NVIDIA OpenShell Gateway (NemoClaw)..."
mkdir -p /data/openshell
chown -R sandbox:sandbox /data/openshell /app
# Ensure the sandbox user has the policy file
cp /app/openclaw-sandbox.yaml /data/openclaw-sandbox.yaml
chown sandbox:sandbox /data/openclaw-sandbox.yaml

# Claude Code Spoofing: Redirect to OpenRouter using StepFun
# Uses OPENROUTER_API_KEY passed from Railway as the 'Anthropic' key.
export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
export ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY"
export ANTHROPIC_MODEL="stepfun/step-3.5-flash"
export ANTHROPIC_API_KEY="" # Clear official key to force custom base URL

# Run gateway in background
gosu sandbox bash -c "openshell-gateway --daemon --data-dir /data/openshell > /data/openshell/gateway.log 2>&1 &"

# Start NemoClaw wrapper
echo "🚀 Starting NemoClaw server with NVIDIA OpenShell support..."
exec gosu sandbox node src/server.js
