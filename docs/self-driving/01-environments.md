# Environments

Code runs in three places: your laptop on the dev environment, an isolated
E2E run on a GitHub runner, and production on the Pi.

## The isolated E2E run

`e2e/scripts/e2e.sh` is one run of the checkout it sits in. CI runs it for
every PR, and you can run it on your Mac. It:

1. builds the backend, the agent and the web app from the checkout;
2. starts the Firebase Auth and Firestore emulators;
3. makes an empty temp directory for threads, things and the agent's
   calendar map;
4. creates `focus.main.agent@gmail.com` in the emulator
   (`server/scripts/test-account.mjs`), with the password named in
   `app/env/e2e.json`. The emulators run as `focus-local-dev`, the dev
   flavor's project, which the web build is made with. The emulator starts
   empty on every run, so the account is new every time, and its password
   opens nothing anywhere else;
5. starts the agent on `:3101` and the backend on `:3100`, with
   `ALLOWED_GOOGLE_EMAILS` set to that one address, and serves the web build
   on `:8100`;
6. runs the Maestro suite in Chrome, skipping flows tagged `calendar`, since
   the agent has no calendar here;
7. on the way out, whatever happened: deletes the user, stops everything and
   removes the temp directory.

Two runs at once share nothing, and no secret is involved. The run's ports
(3100, 3101, 8100) differ from the dev ones, so `make e2e` can run next to a
dev session. It never touches the real `focus-local-dev` project either: the
emulators only borrow its id.

`test-account.mjs` refuses to run unless `FIREBASE_AUTH_EMULATOR_HOST` is
set, so it can never create an account in a real project.

## Local

Local work uses the **dev environment**: the `dev` flavor of the app and the
`focus-local-dev` Firebase project, with the backend and the agent running
on your machine. SETUP.md has the one-time setup (the dev service account
key, `server/.env.local`, `agent/.env.local`, `app/env/dev.json`).

```bash
make install     # npm ci in server/ and agent/, flutter pub get in app/
make dev-server  # npm run start:local in server/, dev Firebase
make dev-agent   # npm run start:local in agent/, on :3002

cd app
flutter run --flavor dev --dart-define-from-file env/dev.json               # iOS or Android
flutter run -d chrome --dart-define-from-file env/dev.json                  # web
```

To try the test login by hand, add `"ENABLE_TEST_LOGIN": "true"` to your
`env/dev.json`, and create an email/password user in `focus-local-dev`.

## App env files

Every `app/env/*.json` sets `FLAVOR`, and `app/lib/environment.dart` reads
it. `FLAVOR` picks the Firebase project (`dev` is focus-local-dev, anything
else is focus-production) for the app and for the background refresh alike.
Outside production it also opens the test doors:

| Define | Effect | Ignored in production |
|---|---|---|
| `TEST_LOGIN_EMAIL`, `TEST_LOGIN_PASSWORD` | the build signs this account in by itself at launch, with no screen, then creates its record on the backend. E2E builds use it | yes |
| `ENABLE_TEST_LOGIN=true` | the **Conta de teste** email form on the sign-in screen, for trying a test account by hand | yes |
| `AUTH_EMULATOR_HOST=host:port` | Firebase Auth goes to the emulator | yes |
| (web, not production) | the semantics tree is built from the first frame, so Maestro can see the page | yes |

A build with no `FLAVOR` counts as production, so a forgotten value keeps
every test door shut.

| File | Tracked | For |
|---|---|---|
| `env/dev.json` | no, from `dev.example.json` | local work on the dev environment |
| `env/e2e.json` | yes | the isolated E2E run: the dev flavor, the Auth emulator, and focus.main.agent@gmail.com signed in at launch. `e2e.sh` sets its `API_BASE_URL` |
| `env/production.json` | no, from `production.example.json` | your production builds; CI writes its own |

## Production

Production is unchanged in how it runs: a push to `main` that touches
`server/`, `agent/` or `app/` deploys that part to the Pi. Under the hood the
three workflows now share `deploy-image.yml`, `.github/actions/pi-ssh` and
`server/deploy/pi-deploy.sh`.

`/health` reports `env` and `version`. Images are built with
`FOCUS_VERSION=<sha>`, and the deploy fails unless the new container answers
`/health` with that sha. A container that restarts but never answers now
fails the workflow, where it used to fail silently.

Create a `production` environment under **Settings → Environments**. Every
deploy job names it, so you can add a required reviewer there if you ever
want a manual gate. The existing secrets and variables from `AGENTS.md` are
unchanged.
