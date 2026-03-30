FROM node:22-bookworm
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gosu \
    procps \
    python3 \
    build-essential \
    zip \
    python3-pip \
    python3.11-venv \
  && rm -rf /var/lib/apt/lists/* \
  && curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | OPENSHELL_INSTALL_DIR=/usr/local/bin sh \
  && curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh \
  && npm install -g nemoclaw @anthropic-ai/claude-code

RUN groupadd -g 1001 sandbox && \
    useradd -u 1001 -g sandbox -m -s /bin/bash sandbox

RUN npm install -g openclaw@v2026.3.24 mcporter

# Install OpenSpace (self-evolving engine)
RUN git clone https://github.com/HKUDS/OpenSpace.git /opt/OpenSpace \
    && pip3 install --break-system-packages --no-cache-dir -e /opt/OpenSpace

# Register OpenSpace MCP server with mcporter for OpenClaw
RUN mcporter config add openspace --command "openspace-mcp" \
    --env OPENSPACE_HOST_SKILL_DIRS="/data/workspace/skills" \
    --env OPENSPACE_WORKSPACE="/opt/OpenSpace"

WORKDIR /app
COPY requirements.txt .
RUN pip3 install --break-system-packages --no-cache-dir -r requirements.txt
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile --prod
COPY src ./src
COPY entrypoint.sh ./entrypoint.sh
COPY git_setup.sh ./git_setup.sh
COPY openclaw-sandbox.yaml ./openclaw-sandbox.yaml
RUN chmod +x ./entrypoint.sh ./git_setup.sh
RUN useradd -m -s /bin/bash openclaw \
  && chown -R openclaw:openclaw /app \
  && mkdir -p /data && chown openclaw:openclaw /data \
  && mkdir -p /home/linuxbrew/.linuxbrew && chown -R openclaw:openclaw /home/linuxbrew
USER openclaw
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
ENV HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
ENV HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"
ENV PORT=8080
ENV OPENCLAW_ENTRY=/usr/local/lib/node_modules/openclaw/dist/entry.js
# Set OpenSpace workspace
ENV OPENSPACE_WORKSPACE="/opt/OpenSpace"
# Set OpenSpace workspace
ENV OPENSPACE_WORKSPACE="/opt/OpenSpace"
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -f http://localhost:8080/setup/healthz || exit 1
USER root
ENTRYPOINT ["./entrypoint.sh"]
