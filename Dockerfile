FROM ghcr.io/openclaw/openclaw:latest

# Install Python for scoring scripts + bc for math
USER root
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends python3 python3-pip bc jq && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create gauntlet directories
RUN mkdir -p /gauntlet/{tasks,results/latest,scripts,workspace} && \
    chown -R node:node /gauntlet

# Copy scripts
COPY --chown=node:node scripts/ /gauntlet/scripts/
RUN chmod +x /gauntlet/scripts/*.sh

# Copy program and README (for reference)
COPY --chown=node:node program.md /gauntlet/program.md
COPY --chown=node:node README.md /gauntlet/README.md

USER node

# Gateway starts automatically via the base image entrypoint
# Workspace, tasks, and results are mounted as volumes
