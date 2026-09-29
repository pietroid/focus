# Self-driving Focus

This is the plan in `_product/record/focus-self-driving-product-strategy.md`
turned into machinery. Focus codes itself, tests itself and takes requests,
and every change leaves proof that a human can watch.

## The road a change travels

```
issue ──▶ pi on the Pi ──▶ PR ──▶ CI ──────────────┐
  label    coder.yml             ci.yml            ├──▶ merge ──▶ release
  `agent`                        e2e.yml ──────────┘           release.yml
                                 (isolated run + video)
```

1. **A request arrives** as a GitHub issue. You label it `agent`. pi, running
   on the Raspberry Pi in a container and in a clone of its own, reads the
   issue and either asks a question on it or changes the code and passes
   `make check-server` and `make check-agent`. The Pi pushes the change to
   `agent/issue-<n>` with its own GitHub credentials, and GitHub opens the PR. Comment
   `/agent <feedback>` on the PR to have it iterate. See [04-coder.md](04-coder.md).
2. **CI** (`ci.yml`) runs `make check-server`, `make check-agent` and
   `make check-app` on every push to any branch. These are the same commands
   you run locally.
3. **E2E** (`e2e.yml`) runs on every push to a branch other than `main`. It
   runs Focus for that commit alone, on the runner. The
   backend, agent and web app are built from that commit. They start on an
   empty data directory, against the Firebase emulators, and the app opens
   already signed in as focus.main.agent@gmail.com. Maestro drives the web app in Chrome on a
   virtual display while ffmpeg records it. The video, the report and the
   screenshots go to a draft release `pr-<n>` of the branch's open PR, and a
   summary goes on the PR.
   Nothing is deployed, and no secret is used.
4. **Merge.** You watch the video and merge. `release.yml` publishes the draft
   as a release, and the deploy workflows put the build in production.
5. **Weekly demo.** A human compiles the week's releases into one demo for
   people who have never seen Focus. See [05-releases-and-demo.md](05-releases-and-demo.md).

## Environments

| | local | E2E run (per PR, on the runner) | production |
|---|---|---|---|
| Code | your checkout | the PR's commit | `main`, on the Pi |
| Data (threads, things) | `e2e/.data/` | a temp dir, deleted after the run | `/opt/focus/data` |
| App build | `dev` flavor, `env/dev.json` | `dev` flavor, `env/e2e.json` | `production` flavor |
| Accounts | `focus-local-dev` | focus.main.agent@gmail.com in a fresh emulator, signed in at launch | `focus-production`, Google sign-in |
| Calendar | the agent's `.env.local` | none, so calendar flows are skipped | production service account |

See [01-environments.md](01-environments.md).

## Guides

1. [Environments](01-environments.md): local, the isolated E2E run, production.
2. [E2E with Maestro on Flutter web](02-e2e-maestro.md)
3. [CI checks](03-ci-checks.md)
4. [The coder](04-coder.md)
5. [Releases and the weekly demo](05-releases-and-demo.md)

## Setup, step by step

Do these in order. The E2E run needs no setup: it uses the Firebase emulators
and no secrets.

### The coder

Merge this work to `main` first. The Pi builds the coder from `origin/main`.
[04-coder.md](04-coder.md#setup) has every command. No GitHub App, no
deploy key and no new secret: the workflow reaches the Pi with the deploy
key it already has, and the Pi pushes with its own GitHub credentials.

1. **Prepare the Raspberry Pi,** as the user that already has `gh` and Docker.
   Clone the repo to `/opt/focus-coder/repo`, separate from the deploy
   checkout. Install `agent/coder/host/focus-coder` into
   `/opt/focus-coder/bin/`, and write `/opt/focus-coder/coder.env` with
   `OPENROUTER_API_KEY` (give it a spend limit) and `CODER_MODEL`. Run
   `gh auth setup-git` so plain `git push` uses gh's credentials.
2. **Create the label.** Go to **Issues → Labels → New label → `agent`**.

### GitHub

3. **Create the `production` environment** under **Settings →
   Environments**. The deploy jobs name it. The existing deploy secrets and
   variables from `AGENTS.md` do not change.
4. **Protect `main`.** Go to **Settings → Rules → New branch ruleset**,
   targeting `main`. Require a pull request, require the status checks
   `server`, `agent`, `app` and `e2e`, and block force pushes and deletions.
   Leave the bypass list empty. In particular, do not add **Repository
   admin**: the Pi pushes with your credentials, and you are an admin.

### Prove it

5. **Locally:** run `make e2e`. See
   [02-e2e-maestro.md](02-e2e-maestro.md#run-it-locally) for the tools to
   install first.
6. **On a branch:** push any branch and open a PR for it. CI and `e2e`
   start from the push. When `e2e` ends, a comment on the PR links to a draft
   release that holds `video.mp4`. Watch the video.
7. **The coder:** open an issue with something small and concrete, for
   example "Rename the Projetos heading to Meus projetos", and label it
   `agent`. It should come back with a PR, or with a question on the issue.
