# Agent Notes

## Project

Focus is a personal productivity system with three parts:

1. **Flutter app** in `app/` — cross-platform control center (iOS, Android, Web).
2. **NestJS backend** in `server/` — REST API, Firebase Auth, Firestore.
3. **AI agent** in `agent/` — separate TypeScript service that replies to threads.

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

## Backend Deployment

- Local dev: `cd server && npm run start:dev` (uses `GOOGLE_APPLICATION_CREDENTIALS`).
- Pi deploy: run `cd server && npm run deploy:prod` directly on the Pi.
- The Pi exposes port `80` via nginx; the NestJS backend is only reachable inside the Docker network.
- The Firebase service account key must live on the Pi at `/opt/focus/secrets/focus-backend-prod.json` and is never committed.

## Agent Deployment

The agent is a separate Express service that runs inside its own Docker container.

- It is **not** exposed to the public internet. It only exposes port `3001` inside the Docker network.
- The backend talks to it at `http://focus-agent:3001`.
- It has **read-only** access to the thread files mounted at `/app/data/threads`.
- It does **not** see the backend's Firebase service account or `.env.production` secrets.

Setup on the Pi:

1. Create the agent environment file from the example:
   ```bash
   cd agent
   cp .env.example .env.production
   ```
2. Deploy the backend as usual; `npm run deploy:prod` now also builds and starts the agent container.

## Web Deployment

The Flutter web app is served by an nginx container (`focus-web`) on the Pi.

1. Deploy the backend first (this also starts nginx):
   ```bash
   # Run on the Pi
   cd server
   npm run deploy:prod
   ```
2. Deploy the web app:

   **Option A — from your dev machine:**
   ```bash
   cd app
   ./scripts/deploy-web.sh pi@<pi-ip>
   ```

   **Option B — locally on the Pi (requires Flutter SDK on the Pi):**
   ```bash
   cd app
   ./scripts/deploy-web-local.sh
   ```
3. Open `http://<pi-ip>` in a browser.

Mobile production builds use `API_BASE_URL=http://<pi-ip>/api/`; web builds use the relative `/api/` and are served from the same origin. Both hit nginx on port `80`, which strips the `/api/` prefix and proxies the requests to the NestJS backend.

## Security

- Never commit Firebase service account JSON keys.
- `app/env/production.json` is gitignored; use `production.example.json` as a template.
- `agent/.env.production` is gitignored; use `agent/.env.example` as a template.
- Generated Firebase config files (`firebase_options_*.dart`, `google-services.json`, `GoogleService-Info.plist`) must be regenerated with `./app/update_firebase_config.sh` after Firebase changes.

## Common Commands

```bash
# App
cd app
flutter pub get
flutter run --flavor production --dart-define-from-file env/production.json

# Backend local
cd server
npm install
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/keys/focus-backend-prod.json"
npm run start:dev

# Agent local
cd agent
npm install
npm run start:dev

# Backend deploy to Pi (run directly on the Pi)
cd server
npm run deploy:prod

# Web deploy to Pi (from your dev machine)
cd app
./scripts/deploy-web.sh pi@<pi-ip>

# Web deploy locally on the Pi (requires Flutter SDK on the Pi)
cd app
./scripts/deploy-web-local.sh
```
