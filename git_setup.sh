#!/bin/bash
echo "🤖 OpenClaw: Configuring self-modification capabilities..."

# Trust the workspace directory
git config --global --add safe.directory /data/workspace
git config --global --add safe.directory /app

# Navigate to workspace
cd /data/workspace || cd /app || exit

# Configure git user
git config --global user.email "openclaw@agent.ai"
git config --global user.name "OpenClaw Agent"

# Set remote with token
if [ -n "$GITHUB_TOKEN" ] && [ -n "$GITHUB_REPO" ]; then
    git remote set-url origin "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git" 2>/dev/null || \
    git remote add origin "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git"
    echo "✅ Git configured! OpenClaw can now self-modify!"
else
    echo "⚠️ GITHUB_TOKEN or GITHUB_REPO not set!"
    exit 1
fi

# Test git access
if git status > /dev/null 2>&1; then
    echo "✅ Git access verified!"
else
    echo "❌ Git access failed!"
    exit 1
fi
