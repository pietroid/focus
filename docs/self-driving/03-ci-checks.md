# CI checks

Code is not handed to a human until the basics pass. The
basics are one command, and it is the same command everywhere.

```bash
make check          # everything, about 3 minutes on a laptop
make check-server   # eslint, tsc, jest, nest build
make check-agent    # tsc, node --test
make check-app      # dart format, flutter analyze, flutter test in each package with tests
```

Run `make check` before you push. The coder runs the same targets as its
gate, and CI runs them on every PR.

## What each target does

| Target | Steps | Fails when |
|---|---|---|
| `check-server` | `npm ci`, `eslint`, `tsc --noEmit`, `jest`, `nest build` | a lint error (typescript-eslint strict and prettier), a type error, a failing spec, a build error |
| `check-agent` | `npm ci`, `tsc`, `node --test dist/**/*.test.js` | a type error or a failing test |
| `check-app` | `flutter pub get`, `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` in `app_ui`, `chat`, `notifications` | unformatted Dart, any analyzer issue (very_good_analysis), a failing test |

The server lint used to have twelve standing errors in
`logging.interceptor.ts` and `thread-markdown.ts`. They are fixed, so the
gate starts green. Keep it that way. A lint rule you disagree with is a
change to `eslint.config.mjs`, not a red build everyone learns to ignore.

A package that gains a `test/` folder has to be added to `FLUTTER_PACKAGES` in
the `Makefile`.

## The workflow

`.github/workflows/ci.yml` has three jobs, `server`, `agent` and `app`. Each
one calls its `make` target, so a failure in CI reproduces locally with the
same command. It runs on every push to every branch, `main` included.

Next to it, `e2e.yml` runs the isolated end-to-end run with its video on
every push to a branch other than `main`
([02-e2e-maestro.md](02-e2e-maestro.md)). The two start at the same time,
and neither waits for the other.

Both start from `push`, not from `pull_request`. The coder's branches are
pushed from the Pi before a PR exists, and its PR is opened with the
workflow's own token, which starts nothing. A push starts everything, and
the check results belong to the commit, so they show on the PR however it
was opened. There is deliberately no `pull_request` trigger: a skipped run
of a required check counts as a pass. The price is that PRs from forks get
no checks.

## Branch protection

Under **Settings → Rules → New branch ruleset**, targeting `main`:

- **Require a pull request before merging.**
- **Require status checks to pass**, and add `server`, `agent`, `app` and
  `e2e`.
- **Block force pushes** and **restrict deletions**.
- **Leave the bypass list empty.** In particular, not **Repository admin**:
  the Pi pushes with your credentials, and must never reach `main`.

Leave "Require approvals" off while you are the only reviewer. Watching the
E2E video and merging is the approval.

## When the agent writes the code

The coder's branches go down exactly this road. Its own gate runs
`make check-server` and `make check-agent` on the Pi before it pushes, and CI
runs every check again on the push ([04-coder.md](04-coder.md)). The agent
never gets a shorter road.
