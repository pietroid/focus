# E2E with Maestro on Flutter web

Every push to a branch other than `main` gets a recorded run of the real
app. The web build is driven in Chrome by Maestro, against a backend and an
agent built from the same commit. When the branch has an open PR, the video
lands on it.
Unit tests tell the machine the code is right. The video shows a person what
the change does.

## Layout

```
e2e/
  firebase.json            Auth + Firestore emulators, run as focus-local-dev
  maestro/
    config.yaml            the suite: every file in flows/
    subflows/launch.yaml   a clean browser
    subflows/signed_in.yaml  waits for the app to open signed in as focus.main.agent@gmail.com
    flows/01_things.yaml   Coisas: write a thing down, rename it
    flows/02_tempo.yaml    Tempo: put a block on the day, finish it (tag: calendar, skipped)
  scripts/
    e2e.sh                 one isolated run: build, start, sign up, test, record, clean up
    publish.sh             CI only: draft release pr-<n> and the comment on the branch's PR
  artifacts/               local run output (gitignored)
```

## What was proven, and how

The whole `e2e.sh` run was done on a Mac in emulator mode. It built all
three parts, started the emulators, created the agent's account, and the Coisas
flow passed in 48 seconds. Then the account was deleted and every port was
freed. That run showed that each of the following works on Flutter web:

- **Text** that Flutter renders as DOM text: tab names, headings, buttons
  with a label.
- **Identifiers** from `Semantics(identifier: ...)`. Maestro's web driver
  reads Flutter's `flt-semantics-identifier` attribute as `id:`.
- **Typing** into Flutter text fields (`tapOn` the field, then `inputText`),
  `eraseText`, and `pressKey: Enter`.
- **Recording** with Maestro's own `startRecording` needs a visible Chrome,
  and a Chrome version the installed Maestro supports. CI records the
  virtual display with ffmpeg instead (see below).

These did not work, and the flows are written around them:

- **Row text.** Flutter web puts a row's merged label into `aria-label`
  whenever the row has child nodes, such as a button. Maestro only reads an
  element's own DOM text, so it cannot see that label. Rows therefore carry
  an identifier with their title: `thing:<title>` on Coisas rows,
  `event:<title>` on timeline cards. Screen readers ignore identifiers, so
  accessibility does not change.
- **Swipes.** On Flutter web, Maestro turns every swipe, element or
  coordinates, into mouse-wheel scrolling, and `Dismissible` ignores the
  wheel. Swipe-to-finish and swipe-to-delete cannot be tested on web.
  Nothing needs deleting anyway, since every run starts empty.

Not yet run: the CI job itself on a GitHub runner, which runs on the first
PR. The Tempo flow is kept but skipped, because it needs an agent with a
calendar service account, and the isolated run has none.

## How CI records

`e2e.yml` runs `e2e.sh` inside `xvfb-run`, which gives it a 1280x800 virtual
display. Maestro opens a real, visible Chrome on that display, and `e2e.sh`
records it with `ffmpeg -f x11grab`. The recording runs in real time and
catches everything on screen, including a failure page after a flow dies. It
does not depend on Maestro's recorder.

Maestro 2.10 includes Chrome DevTools support for Chrome 145 to 147 only.
`e2e.sh` sets `SE_BROWSER_VERSION=147`, and Selenium downloads Chrome for
Testing at that version. When you upgrade Maestro (`MAESTRO_VERSION` in
`e2e.yml`), look at which `selenium-devtools-vNNN` jars it ships and move
`SE_BROWSER_VERSION` to match.

## Run it locally

Install once:

```bash
brew tap mobile-dev-inc/tap && brew install mobile-dev-inc/tap/maestro   # 2.10.0 when written
java -version    # 17 or newer, for Maestro and the emulators
```

Then:

```bash
make e2e                                            # the suite
make e2e FLOWS=e2e/maestro/flows/01_things.yaml     # one flow
E2E_SKIP_BUILD=1 make e2e                           # reuse the last builds while writing flows
```

On a Mac, Chrome opens in a window you can watch. Local runs are not
recorded, because `E2E_RECORD` needs Linux and a virtual display. Output lands
in `e2e/artifacts/<timestamp>/`:

```
report.xml                                  JUnit, one test case per flow
health.json                                 which backend build answered
logs/{server,agent,web,emulators,build-*}.log
<run>/<flow>/takeScreenshot/*.png           frames each flow saves on purpose
<run>/<flow>/screenshots/step-*.png         Maestro's own, on failure
<run>/<flow>/screen-hierarchy/*.json        what Maestro could see, on failure
```

## Writing flows

- **Find by what the user sees** when it is DOM text: tab names, headings,
  labelled buttons, dialog words. `tapOn: Coisas` is fine.
- **Everything else gets an identifier.** Current ids: `orb`,
  `prompt-field`, `prompt-send`, `thing:<title>`, `event:<title>`,
  `event-done`, and `test-login-email`, `test-login-password`,
  `test-login-submit` on the hand-test form. Add one
  with `Semantics(container: true, identifier: ...)`. `container: true`
  matters, because without it the identifier can merge into a parent node.
- **There is no login step.** The E2E build signs focus.main.agent@gmail.com
  in by itself at launch, so every flow starts with `launch.yaml` and then
  `signed_in.yaml`. The landing page's demo phone shows the same tab names,
  so `signed_in.yaml` also checks that the landing headline is gone.
- **Make names unique** with `evalScript`, for example
  `${output.thing = 'Comprar pão E2E ' + Math.floor(Math.random() * 100000)}`.
- **Tag flows that need the calendar** with `calendar`. The isolated run skips them.
- **Save the moments that matter** with `takeScreenshot: <name>`. They go to
  the PR's draft release.
- **Allow time for Google.** A calendar write can take a few seconds, so use
  `extendedWaitUntil` with a 45-second timeout.
- **No swipes.** See above.

When a step cannot find something, open that step's
`screen-hierarchy/*.json`. It lists exactly what Maestro saw: `text` and
`resource-id` for every node.

## Troubleshooting

- **"You are using a no-op implementation of the CDP".** The Chrome version
  is outside the installed Maestro's range. See `SE_BROWSER_VERSION` above.
- **The run stops in `signed_in.yaml` on the landing page.** The build's
  own sign-in failed, or the backend refused the account. The first means
  the emulator had no such user: see `logs/emulators.log`. The second shows
  as 401s in `logs/server.log`: `e2e.sh` sets `ALLOWED_GOOGLE_EMAILS` to the
  account, so check it did. A refused signup also makes the app retry in a
  tight loop, more than a thousand requests in a few minutes. That is a real
  bug, worth fixing on its own.
- **A port is already in use.** Something is on 3100, 3101, 8100, 9099 or
  8080. Stop it, or change the ports at the top of `e2e.sh`.
