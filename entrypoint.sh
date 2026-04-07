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

# Pass GOOGLE_API_KEY as GEMINI_API_KEY if not already set (Google plugin looks for GEMINI_API_KEY)
if [ -n "$GOOGLE_API_KEY" ] && [ -z "$GEMINI_API_KEY" ]; then
  export GEMINI_API_KEY="$GOOGLE_API_KEY"
  echo "🔑 Mapped GOOGLE_API_KEY → GEMINI_API_KEY for Google plugin"
fi

# Claude Code Spoofing: Redirect to OpenRouter using StepFun
# Uses OPENROUTER_API_KEY passed from Railway as the 'Anthropic' key.
export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
export ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY"
export ANTHROPIC_MODEL="stepfun/step-3.5-flash"
export ANTHROPIC_API_KEY="" # Clear official key to force custom base URL

# Run gateway in background
gosu sandbox bash -c "openshell-gateway --daemon --data-dir /data/openshell > /data/openshell/gateway.log 2>&1 &"

# Validate Gemini API key on startup
GEMINI_KEY="${GEMINI_API_KEY:-$GOOGLE_API_KEY}"
if [ -n "$GEMINI_KEY" ]; then
  echo "🔑 Testing Gemini API key (first 8 chars: ${GEMINI_KEY:0:8}...)..."
  TEST_RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -d '{"contents":[{"parts":[{"text":"hi"}]}]}' \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_KEY}" 2>/dev/null || echo "000")
  if [ "$TEST_RESULT" = "200" ]; then
    echo "✅ Gemini API key is VALID (HTTP 200)"
  else
    echo "❌ Gemini API key test FAILED (HTTP $TEST_RESULT) — check if key is correct in Railway"
  fi
else
  echo "⚠️ No GEMINI_API_KEY or GOOGLE_API_KEY found in environment!"
fi

# OpenClaw setup & auth configuration via CLI (bypassing doctor wipes)
gosu sandbox bash -c '
  # Force-reset Google auth profile to clear any permanent failure blacklist
  openclaw config delete auth.profiles.google:default 2>/dev/null || true

  # Auth profiles: Google, NVIDIA, OpenRouter
  # Use Config set to ensure provider/mode, and explicit delete of apiKey to force Env Var use
  openclaw config set auth.profiles.google:default.provider google 2>/dev/null || true
  openclaw config set auth.profiles.google:default.mode api_key 2>/dev/null || true
  openclaw config delete auth.profiles.google:default.apiKey 2>/dev/null || true
  
  openclaw config set auth.profiles.nvidia:default.provider nvidia 2>/dev/null || true
  openclaw config set auth.profiles.nvidia:default.mode api_key 2>/dev/null || true
  openclaw config delete auth.profiles.nvidia:default.apiKey 2>/dev/null || true

  openclaw config set auth.profiles.openrouter:default.provider openrouter 2>/dev/null || true
  openclaw config set auth.profiles.openrouter:default.mode api_key 2>/dev/null || true
  openclaw config delete auth.profiles.openrouter:default.apiKey 2>/dev/null || true

  # Enable Google plugin
  openclaw config set plugins.entries.google.enabled true 2>/dev/null || true

  # PRIMARY MODEL: google/gemini-2.5-flash (free via Google AI Studio)
  openclaw config set agents.defaults.model.primary "google/gemini-2.5-flash" 2>/dev/null || true

  # Remove stale model entries that cause fallback to rate-limited OpenRouter
  openclaw config delete agents.defaults.models."nvidia/nemotron-3-super" 2>/dev/null || true
  openclaw config delete agents.defaults.models."nvidia/nemotron-3-super-120b-a12b:free" 2>/dev/null || true
  openclaw config delete agents.defaults.models."openrouter/nvidia/nemotron-3-super-120b-a12b:free" 2>/dev/null || true
  openclaw config delete agents.defaults.models."nvidia/cosmos-reason2-8b" 2>/dev/null || true
  openclaw config delete agents.defaults.models."google/gemini-3-flash-preview" 2>/dev/null || true
  openclaw config delete agents.defaults.models."deepseek-ai/deepseek-r1" 2>/dev/null || true
  openclaw config delete agents.defaults.models."openrouter/deepseek-ai/deepseek-r1" 2>/dev/null || true

  # Free model aliases
  openclaw config set agents.defaults.models."google/gemini-2.5-flash".alias gemini-flash 2>/dev/null || true
  openclaw config set agents.defaults.models."openrouter/nvidia/nemotron-3-nano-30b-a3b:free".alias coding-primary 2>/dev/null || true
  openclaw config set agents.defaults.models."openrouter/deepseek-ai/deepseek-r1:free".alias reasoning-primary 2>/dev/null || true
  openclaw config set agents.defaults.models."openrouter/mistralai/devstral-2:free".alias coding-fallback 2>/dev/null || true
  openclaw config set agents.defaults.models."openrouter/stepfun/step-3.5-flash:free".alias claude-substitute 2>/dev/null || true
  openclaw config set agents.defaults.models."openrouter/meta-llama/llama-3.3-70b-instruct:free".alias creative 2>/dev/null || true
  openclaw config set agents.defaults.models."openrouter/qwen/qwen3.6-plus:free".alias general 2>/dev/null || true
'

# Generate a gateway token if one wasn't fed by environment
export GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-$(head -c 32 /dev/random | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)}"

echo "🚀 Starting Node Wrapper (Server/Serve functionality)..."
exec gosu sandbox node src/server.js
