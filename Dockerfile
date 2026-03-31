# Rewritten Dockerfile to use uv for Python installation and avoid stale apt cache
# This Dockerfile combines Python setup into a single RUN to prevent reuse of old cached layers
FROM node:22-bookworm

# Copy requirements early for Python installation during build
COPY requirements.txt /tmp/requirements.txt

# Install system dependencies, OpenShell, uv, Python 3.12 via uv, OpenSpace, and Python requirements in one layer
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gosu \
        procps \
        build-essential \
        zip \
    && rm -rf /var/lib/apt/lists/* \
    && curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | OPENSHELL_INSTALL_DIR=/usr/local/bin sh \
    && curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh \
    && uv python install 3.12 \
    && uv venv /opt/openspace-venv \
    && uv pip install --python /opt/openspace-venv/bin/python --upgrade pip setuptools wheel \
    && git clone https://github.com/HKUDS/OpenSpace.git /opt/OpenSpace \
    && uv pip install --python /opt/openspace-venv/bin/python -e /opt/OpenSpace \
    && uv pip install --python /opt/openspace-venv/bin/python --no-cache-dir -r /tmp/requirements.txt

# Add the OpenSpace virtual environment to PATH
ENV PATH="/opt/openspace-venv/bin:${PATH}"
ENV OPENSPACE_WORKSPACE="/opt/OpenSpace"

# Install Node.js global packages (OpenClaw and mcporter)
RUN npm install -g openclaw@v2026.3.24 mcporter

# Register OpenSpace MCP server with mcporter
RUN mcporter config add openspace --command "openspace-mcp" \
    --env OPENSPACE_HOST_SKILL_DIRS="/data/workspace/skills" \
    --env OPENSPACE_WORKSPACE="/opt/OpenSpace"

# Create system users: sandbox (for OpenShell confinement) and openclaw (for app runtime)
RUN groupadd -g 1001 sandbox && \
    useradd -u 1001 -g sandbox -m -s /bin/bash sandbox && \
    useradd -m -s /bin/bash openclaw

WORKDIR /app

# Copy application source and configuration
COPY package.json pnpm-lock.yaml ./
COPY src ./src
COPY entrypoint.sh ./entrypoint.sh
COPY git_setup.sh ./git_setup.sh
COPY openclaw-sandbox.yaml ./openclaw-sandbox.yaml
COPY requirements.txt ./

# Install Node dependencies, set permissions, and prepare Homebrew directory
RUN corepack enable && pnpm install --frozen-lockfile --prod && \
    chmod +x ./entrypoint.sh ./git_setup.sh && \
    chown -R openclaw:openclaw /app && \
    mkdir -p /data && chown openclaw:openclaw /data && \
    mkdir -p /home/linuxbrew/.linuxbrew && chown -R openclaw:openclaw /home/linuxbrew

# Switch to openclaw user for Homebrew installation and runtime
USER openclaw

# Install Homebrew (Linuxbrew)
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Environment setup
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
ENV HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
ENV HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"

ENV PORT=8080
ENV OPENCLAW_ENTRY=/usr/local/lib/node_modules/openclaw/dist/entry.js

EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -f http://localhost:8080/setup/healthz || exit 1

# Switch back to root for entrypoint which uses gosu
USER root

ENTRYPOINT ["./entrypoint.sh"]


