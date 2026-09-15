# Agent Notes

## Project

Focus is a personal productivity system with three parts:

1. **Flutter app** in `app/` — cross-platform control center (iOS, Android, Web).
2. **NestJS backend** in `server/` — REST API, Firebase Auth, Firestore.
3. **AI agent** — planned; will integrate via tools.

## Stack

- Frontend: Flutter + BLoC + go_router + Firebase Auth (Google Sign-In).
- Backend: NestJS + TypeScript + Firebase Admin SDK + Firestore.
- Deployment: Docker on a Raspberry Pi (not Google Cloud Run).

## Firebase

- Production project: `focus-production`
- Development project: `focus-development` (placeholder, not actively used)
- Bundle IDs:
  - Production: `com.pietroid.focus`
  - Development: `com.pietroid.focus.dev`

## Backend Deployment

- Local dev: `cd server && npm run start:dev` (uses `GOOGLE_APPLICATION_CREDENTIALS`).
- Pi deploy: `cd server && npm run deploy:prod -- --host <pi-host>`.
- The Pi exposes port `3000`.
- The Firebase service account key must live on the Pi at `/opt/focus/secrets/focus-backend-prod.json` and is never committed.

## Security

- Never commit Firebase service account JSON keys.
- `app/env/production.json` is gitignored; use `production.example.json` as a template.
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

# Backend deploy to Pi
cd server
npm run deploy:prod -- --host your-pi-hostname
```
