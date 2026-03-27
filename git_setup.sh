#!/bin/bash
echo "🤖 OpenClaw: Configuring self-modification capabilities..."

cd /data/workspace || cd /app || exit

git config --global user.email "openclaw@agent.ai"
git config --global user.name "OpenClaw Agent"

if [ -n "$GITHUB_TOKEN" ] && [ -n "$GITHUB_REPO" ]; then
    git remote set-url origin "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git"
    echo "✅ Git configured! OpenClaw can now self-modify!"
else
    echo "⚠️ GITHUB_TOKEN or GITHUB_REPO not set!"
fi

git status || echo "❌ Git access failed!"
