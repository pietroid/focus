# The coder's container: pi, the tools `make check-server` and
# `make check-agent` need, and the coder's own entry point.
#
# Built on the Raspberry Pi by host/focus-coder, always from origin/main's
# agent/ directory, never from the branch being edited:
#   git archive origin/main:agent | docker build -t focus-coder -f coder/Dockerfile -
#
# The run mounts a fresh clone at /workspace and an output directory at /out,
# and nothing else. See docs/self-driving/04-coder.md.
FROM node:24-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates git make ripgrep \
  && rm -rf /var/lib/apt/lists/*

# Pinned. Move it on purpose, after reading pi's changelog.
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@0.87.1

WORKDIR /coder
COPY package*.json tsconfig.json ./
RUN npm ci --no-audit --no-fund
COPY src ./src
RUN npm run build && npm prune --omit=dev

# The run passes --user so files in the mounts belong to the host's coder
# user. HOME is a throwaway directory for pi's config and npm's cache.
ENV HOME=/tmp/home
RUN mkdir -p /tmp/home && chmod 1777 /tmp/home
WORKDIR /workspace
ENTRYPOINT ["node", "/coder/dist/coder/main.js"]
