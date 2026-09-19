# Agent Notes

## Project

Focus is a personal productivity system with three parts:

1. **Flutter app** in `app/` — cross-platform control center (iOS, Android, Web).
2. **NestJS backend** in `server/` — REST API, Firebase Auth, Firestore.
3. **AI agent** in `agent/` — separate TypeScript service that runs the model
   and its tools. It has no UI opinions and no access to the thread files.

### Language

Everything the user reads is in Brazilian Portuguese: app strings, the trees
the server builds, the tool summaries the approval card shows, and the model's
own replies. Code, comments, commits and this file stay in English. A new
user-facing string in English is a bug.

## Stack

- Frontend: Flutter + BLoC + go_router + Firebase Auth (Google Sign-In).
- Backend: NestJS + TypeScript + Firebase Admin SDK + Firestore.
- Agent: Express + TypeScript, internal HTTP service (no public exposure).
- Deployment: Docker on a Raspberry Pi (not Google Cloud Run).

## Firebase

- Production project: `focus-production`
- Development project: `focus-development` (placeholder, not actively used)
- Bundle IDs:
  - Production: `com.pietroid.focus`
  - Development: `com.pietroid.focus.dev`

## Deployment Overview

Deployment is fully SSH-based. Everything is built on an x64 machine (your dev
machine or a GitHub Actions runner) and transferred to the Pi over SSH.

There are two ways to deploy:

1. **GitHub Actions (recommended)** — push to `main` and let GitHub build the
   Docker images and the Flutter web bundle, then copy them to the Pi over SSH.
2. **Manual / local** — build on your dev machine and copy to the Pi with the
   same scripts the workflows use.

Flutter web **cannot** be built on a Raspberry Pi (the Flutter toolchain is not
available or too slow for ARM). Because of this, the web app is always built on
an x64 machine and the resulting static files are copied to the Pi.

The backend and agent are also built on the x64 runner as ARM64 Docker images
and transferred to the Pi as gzipped `docker save` archives.

## GitHub Actions Deployment

Three separate workflows run on pushes to `main`:

- `.github/workflows/deploy-server.yml` — builds `focus-backend` for ARM64,
  exports it, copies it to the Pi, loads it, and restarts the backend and nginx.
- `.github/workflows/deploy-agent.yml` — same for `focus-agent`.
- `.github/workflows/deploy-app.yml` — builds the Flutter web app, rsyncs the
  static files to the Pi, and reloads nginx.

All three can also be triggered manually from the GitHub Actions tab
(`workflow_dispatch`).

### How it works

1. **Server and agent images** are built on GitHub's `ubuntu-latest` runner as
   ARM64 images (`linux/arm64`) using Docker Buildx + QEMU. They are saved with
   `docker save`, gzipped, and copied to the Pi with `scp`.
2. On the Pi, the archive is loaded with `docker load`, and the relevant
   container is restarted with `docker compose up -d`.
3. **Flutter web** is built with the stable Flutter SDK on the same GitHub
   runner. It produces a static `build/web/` directory, which is rsynced to
   `/opt/focus/web/` on the Pi.
4. The app workflow tells the running `focus-web` nginx container to reload.

> **Performance note:** building ARM64 images on an x64 runner via QEMU is
> slower than building natively. If your repository is public, you can switch
> the workflows to `runs-on: ubuntu-24.04-arm` to build natively on ARM64 and
> skip QEMU.

### SSH key setup

The same SSH key is used by GitHub Actions and by your local machine. For
stronger security you can create a separate key for GitHub Actions, but one key
is enough for a personal project.

On your local machine:

```bash
# Generate a dedicated key pair (no passphrase, or use ssh-agent to cache it)
ssh-keygen -t ed25519 -C "focus-deploy" -f ~/.ssh/focus_pi

# Copy the public key to the Pi so passwordless login works
ssh-copy-id -i ~/.ssh/focus_pi.pub pi@<pi-ip>

# Add a convenient SSH config entry
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat >> ~/.ssh/config <<EOF
Host focus-pi
    HostName <pi-ip>
    User pi
    IdentityFile ~/.ssh/focus_pi
    StrictHostKeyChecking accept-new
EOF
chmod 600 ~/.ssh/config

# Test passwordless login
ssh focus-pi
```

Then add the **private key** to GitHub:

1. Open the repository on GitHub → **Settings → Secrets and variables → Actions**.
2. Click **New repository secret**.
3. Name: `PI_SSH_PRIVATE_KEY`
4. Value: the full contents of `~/.ssh/focus_pi` (the private key, not `.pub`).

### Harden SSH on the Pi

Because the Pi is reachable over SSH, disable password authentication so only
keys can log in.

On the Pi:

```bash
sudo nano /etc/ssh/sshd_config
```

Set or ensure these lines:

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
```

Then restart the SSH service:

```bash
sudo systemctl restart ssh
# or on older systems: sudo systemctl restart sshd
```

Keep your existing terminal open while testing login from another window, so
you don't lock yourself out.

Optional extras:

- **fail2ban**: bans IPs after repeated failed login attempts.
  ```bash
  sudo apt install fail2ban
  sudo systemctl enable --now fail2ban
  ```
- **Non-default SSH port**: changes the SSH port from 22 to something else in
  `/etc/ssh/sshd_config`. Remember to update the `PI_HOST` / SSH config on your
  machines accordingly (e.g., `HostName <pi-ip>:2222`).
- **Firewall**: allow only SSH, HTTP, and HTTPS.
  ```bash
  sudo apt install ufw
  sudo ufw default deny incoming
  sudo ufw allow 22/tcp    # or your custom SSH port
  sudo ufw allow 80/tcp
  sudo ufw enable
  ```

### Required GitHub configuration

Repository secrets:

| Secret | Purpose |
|--------|---------|
| `PI_SSH_PRIVATE_KEY` | SSH private key that can log in to the Pi as `PI_USER`. |

Repository variables (Settings → Secrets and variables → Actions):

| Variable | Purpose | Example |
|----------|---------|---------|
| `PI_HOST` | Hostname or IP of the Pi. | `192.168.1.42` or `pi.local` |
| `PI_USER` | SSH user on the Pi. | `pi` |
| `PI_REPO_PATH` | Path where this repo is cloned on the Pi. Defaults to `/home/<PI_USER>/focus`. | `/home/pi/focus` |
| `GOOGLE_SIGN_IN_CLIENT_ID` | Firebase web client ID used by the Flutter web build. | `123-abc.apps.googleusercontent.com` |
| `PROJECT_ID` | Firebase project ID. | `focus-production` |
| `BACKEND_SERVICE_ACCOUNT` | Service account email for the backend. | `focus-backend@focus-production.iam.gserviceaccount.com` |

### Required Pi setup

1. Clone the repo on the Pi at `PI_REPO_PATH`.
2. Place the Firebase service account key on the Pi:
   ```bash
   sudo mkdir -p /opt/focus/secrets
   # copy focus-backend-prod.json to /opt/focus/secrets/
   ```
3. Create the backend environment file:
   ```bash
   cd server
   cp .env.example .env.production
   # fill in the production values
   ```
4. Create the agent environment file:
   ```bash
   cd agent
   cp .env.example .env.production
   # fill in the production values
   ```
5. Ensure the SSH user can write to `/opt/focus/web`:
   ```bash
   sudo mkdir -p /opt/focus/web
   sudo chown -R "$USER:$USER" /opt/focus/web
   ```
6. Create the thread data directory. Only the backend mounts it; the agent
   is given the thread it needs in each request.
   ```bash
   sudo mkdir -p /opt/focus/data/threads
   sudo chown -R "$USER:$USER" /opt/focus/data
   ```
7. Install Docker and docker compose on the Pi.

After the first server deploy, the `focus-web` nginx container will be running.
Subsequent app deploys will sync new web files and reload nginx.

## Architecture: who owns what

The split is one sentence: **the agent gets reliable data, the server decides
what the user sees.**

```
app  ──POST /threads/:slug/messages──▶  server
                                        │ builds the prompt (persona, catalog,
                                        │ hygiene rules, thread history)
                                        ▼
                                       agent  POST /generate
                                        │ runs the model, executes every tool
                                        │ it asks for, loops until there is an
                                        │ answer; returns { raw, toolTrace }
                                        ▼
                                       server parses → validates → scrubs → stores
                                        │
app  ◀──────── thread with a clean A2UI tree ─────────┘
```

### The server owns A2UI

Everything under `server/src/a2ui/` is the single source of truth:

- `a2ui.catalog.ts` — the components, colour roles, icon names and action
  types. The system prompt is **generated from** this file, so the prompt and
  the validator can never describe different catalogs.
- `a2ui-prompt.service.ts` — persona, catalog, the rules about what the user
  must never read, and the history (replayed as prose, not as stored JSON).
- `a2ui-parser.service.ts` — recovers a tree from whatever the model actually
  said: bare JSON, a code fence, JSON buried in prose, or plain prose. It
  reports which rung of that ladder it landed on as `parseStrategy`.
- `a2ui-validation.service.ts` — drops unknown components, strips unknown
  props, and scrubs user-facing strings of tool names, JSON, ids and markdown.
- `a2ui.builders.ts` — the few trees the server writes itself, for the turn
  where the model never answered at all.

The Flutter app implements the other half of the same catalog in
`packages/chat/lib/src/widgets/a2ui_renderer.dart` and
`packages/app_ui/lib/src/app_icons/a2ui_icons.dart`. The icon lists are checked
against each other by `packages/app_ui/test/a2ui_icons_test.dart`, which reads
the server's source directly.

### The agent owns tools

`agent/` no longer knows what A2UI is, has no prompt of its own, and no longer
reads the thread files. It exposes two routes on the private Docker network:

- `GET /tools` — name and description for each tool. The server asks rather
  than keeping a copy, so adding a tool is a one-file change.
- `POST /generate` — runs the prompt the server built, executing every tool the
  model calls inline and returning `{ raw, toolTrace }`.

There is no approval step. A tool runs the moment the model asks for it, and
the model writes the sentence about it with the result already in hand, so the
user reads what happened rather than what was proposed. Each tool in
`agent/src/services/tools/` carries its own OpenRouter definition and its own
`summarize()`, which is the line a trace reads back in plain Portuguese.

### Actions

A rendered component fires an action; the app posts it verbatim to
`POST /threads/:slug/actions` and renders the thread that comes back. The app
interprets exactly two of them itself — `dismiss` and `openUrl` — because
neither needs the server.

| Action | Who handles it |
|--------|----------------|
| `reply` | Server: appends the text as a user message and answers it. |
| `thread` (`solve`/`reopen`/`rename`/`delete`) | Server alone. No agent call. |
| `dismiss`, `openUrl` | App only. The server 400s if one arrives. |

An action type outside the catalog is dropped by the validator, taking its
component with it, so a button a model invented cannot fire anything.

Only the last turn's actions are live. The app disables buttons on every
message above it: they belong to a moment the conversation has already moved
past.

### Observability

Every turn gets a trace id (`t_<base36>_<hex>`), minted in the controller and
passed to the agent in the `x-focus-trace-id` header. Both containers log
one-line JSON under it, so one command replays a whole turn in order:

```bash
docker logs focus-backend & docker logs focus-agent | grep t_mu7hizeb_65a155d1
```

The turn is also written to
`<thread>/traces/<traceId>.json` and readable at
`GET /threads/:slug/traces/:traceId`. The trace id is stored on the message
itself and logged by the app, so a screenshot is enough to find the turn
behind it.

Events worth knowing: `prompt.built`, `agent.generate.start/ok/fail`,
`tool.start/ok/fail`, `tool.awaitingApproval`, `a2ui.parse`, `a2ui.repaired`
(every repair and rejection, in full), `a2ui.validated`, `turn.unavailable`.

### Integrations

- Replies are generated via the [OpenRouter](https://openrouter.ai/) API.
  Configure `OPENROUTER_API_KEY` and `OPENROUTER_MODEL` in
  `agent/.env.production`. Without a key the agent returns 502 and the server
  shows a written "could not reach my brain" message rather than a blank turn.
- **Google Calendar** connects via a service account or OAuth2 refresh token.
  Set `GOOGLE_CALENDAR_SERVICE_ACCOUNT_JSON` /
  `GOOGLE_CALENDAR_SERVICE_ACCOUNT_KEY` or `GOOGLE_CALENDAR_REFRESH_TOKEN`
  plus client credentials. Use `GOOGLE_CALENDAR_ID` to target a specific
  calendar (defaults to `primary`).
- **Web Search** works best with **Serper.dev** or the **Brave Search API**.
  Set `WEB_SEARCH_API_KEY` and `WEB_SEARCH_API_BASE_URL`. Without a key it
  falls back to scraping DuckDuckGo's HTML, which is fine locally and brittle
  in production.

Integration secrets live only in `agent/.env.production`. The server never
holds them and never executes an integration.

## Manual / Local Deployment

These commands are useful for testing or when you do not want to use GitHub
Actions.

### Backend + agent (build locally on your dev machine)

Build the images on your machine and copy them to the Pi:

```bash
cd server
# Build ARM64 image
docker buildx build --platform linux/arm64 -t focus-backend:latest .
docker save focus-backend:latest | gzip > focus-backend.tar.gz
scp focus-backend.tar.gz pi@<pi-ip>:/tmp/

# On the Pi, load and start
ssh pi@<pi-ip> "docker load < /tmp/focus-backend.tar.gz && cd /home/pi/focus/server && docker compose up -d focus-backend focus-web"
```

For the agent, do the same from the `agent/` directory with `focus-agent:latest`
and `docker compose up -d focus-agent`.

### Web app (from your dev machine)

Because Flutter web cannot be built on the Pi, build it locally and rsync it:

```bash
cd app
./scripts/deploy-web.sh pi@<pi-ip>
# or, if you created the SSH config entry above:
./scripts/deploy-web.sh focus-pi
```

This builds `build/web/` on your machine and copies it to `/opt/focus/web/` on
the Pi, then reloads nginx.

## Image transfer options

The current workflows use **`docker save | gzip` + `scp` + `docker load`**.
This avoids any container registry but transfers the whole image every deploy.
For these small Node images that is fine over a home network.

The alternative is a **registry pull** (`ghcr.io`, Docker Hub, etc.): push the
image from the runner, then run `docker compose pull` on the Pi. This is faster
and cache-friendly, but requires a registry and possibly authentication.

For Flutter web there is no image; the static files are copied with `rsync`.

## Web / nginx routing

The Pi exposes port `80` via nginx. Static files are served from
`/opt/focus/web`, and requests to `/api/` are proxied to the
`focus-backend:3000` container.

Mobile production builds use `API_BASE_URL=http://<pi-ip>/api/`; web builds use
the relative `/api/` and are served from the same origin. Both hit nginx on
port `80`, which strips the `/api/` prefix and proxies the requests to the
NestJS backend.

## Security

- Never commit Firebase service account JSON keys.
- `app/env/production.json` is gitignored; use `production.example.json` as a template.
- `agent/.env.production` is gitignored; use `agent/.env.example` as a template.
- The SSH deploy key can log in to the Pi. Keep the private key safe and limit
  what the Pi user can do (do not give it root unless necessary).
- `app/lib/firebase_options_production.dart` is tracked (it only contains public Firebase client API keys). Other generated Firebase config files (`firebase_options_development.dart`, `google-services.json`, `GoogleService-Info.plist`) remain gitignored and must be regenerated with `./app/update_firebase_config.sh` after Firebase changes.

## Common Commands

```bash
# App local dev
cd app
flutter pub get
flutter run --flavor production --dart-define-from-file env/production.json

# Backend local dev
cd server
npm install
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/keys/focus-backend-prod.json"
npm run start:dev

# Agent local dev
cd agent
npm install
npm run start:dev

# Web deploy from your dev machine
cd app
./scripts/deploy-web.sh focus-pi
```
