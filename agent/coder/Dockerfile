# The coder's container: pi, the tools `make check-server` and
# `make check-agent` need, and the coder's own entry point.
#
# Built on the Raspberry Pi by host/focus-coder, always from origin/main's
# agent/ directory, never from the branch being edited:
#   git archive origin/main:agent | docker build -t focus-coder -f coder/Dockerfile -
#
# The run mounts a fresh clone at /workspace and an output directory at /out,
# and nothing else. See docs/self-driving/04-coder.md.

# Only the coder's own files are compiled (tsconfig.coder.json). They use
# nothing but Node's built-ins, and compiling the whole agent, with Google's
# API types, runs a small Pi out of memory.
FROM node:24-bookworm-slim AS build
WORKDIR /coder
COPY package*.json tsconfig.json tsconfig.coder.json ./
RUN npm ci --no-audit --no-fund
COPY src ./src
RUN npx tsc -p tsconfig.coder.json

FROM node:24-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates git make ripgrep \
  && rm -rf /var/lib/apt/lists/*

# Pinned. Move it on purpose, after reading pi's changelog.
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@0.87.1

# The coder has no dependencies at run time, only the compiled files.
COPY --from=build /coder/dist-coder /coder/dist

# The heaviest check, the server's type check, needs about 330 MB. Node picks
# a smaller heap by itself inside a capped container, so name one. On a
# bigger machine, raise it with NODE_OPTIONS in coder.env.
ENV NODE_OPTIONS=--max-old-space-size=400

# The run passes --user so files in the mounts belong to the host's user.
# HOME is a throwaway directory for pi's config and npm's cache.
ENV HOME=/tmp/home
RUN mkdir -p /tmp/home && chmod 1777 /tmp/home
WORKDIR /workspace
ENTRYPOINT ["node", "/coder/dist/coder/main.js"]
