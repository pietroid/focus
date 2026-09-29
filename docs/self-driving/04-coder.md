# The coder

Focus's coding agent. [pi](https://pi.dev) does the editing, on the Raspberry
Pi, in a container, in a clone of the repository that belongs only to the
coder. The deploy checkout at `~/focus` is never touched. The Pi pushes the
result to the branch with the GitHub credentials it already has, through gh.
GitHub decides when a run starts, and opens the PR afterwards.

| Piece | Where | What it does |
|---|---|---|
| `.github/workflows/coder.yml` | GitHub | decides when to run, SSHes to the Pi, opens the PR or comments |
| `agent/coder/host/focus-coder` | the Pi, `/opt/focus-coder/bin/` | the only thing the coder's SSH key can run: clone, build the image, run the container, check, commit and push, hand back the output |
| `agent/coder/Dockerfile` | the Pi, image `focus-coder` | pi 0.87.1, git, make, Node 24, and the entry point below |
| `agent/src/coder/` | inside the container | reads the issue, runs pi, runs the gate, writes the patch, the result and the transcript |

## Using it

| You do | It does |
|---|---|
| Label an issue `agent` | reads the issue and its comments, then opens a PR on `agent/issue-<n>`, or asks a question on the issue |
| Reply on that issue | picks up from the conversation. If its branch exists, it keeps working there and pushes to the same PR |
| Comment `/agent <feedback>` on its PR | reads the PR conversation and pushes a new commit |

Only the repository owner can trigger it. The workflow checks who labelled
or commented, not just what was written.

Every push to a branch other than `main` starts CI and the isolated E2E run,
whoever pushed it, so the agent's branches go down the same road as yours:
CI, E2E with its video, your review, merge, release. Every PR body links to pi's whole
session as `transcript.html` in the run's `coder-<id>` artifact. If
`make check-server` or `check-agent` is still red after two fix rounds, the
PR opens as a draft and says why.

It works best on a request with a clear end: "the Coisas heading should read
Minhas coisas". Say what the user should see, in Portuguese when it is a
string. When the request is open, it asks instead of guessing.

## How a run works

1. **route** (GitHub) works out the mode, the branch, and whether that branch
   already exists.
2. **think** (GitHub, waiting on the Pi) opens the deploy tunnel with the
   deploy key and runs `run <id> <mode> <issue> <pr> <start-ref>
   <continuing> <push-branch>`. On the Pi, `focus-coder`:
   - fetches `/opt/focus-coder/repo`;
   - builds the `focus-coder` image from **`origin/main`**. A branch the agent
     wrote never gets to change the tool that runs it;
   - clones `start-ref` into `/opt/focus-coder/runs/<id>/work`, using the repo
     as a local cache;
   - runs the container with only that clone at `/workspace` and an output
     directory at `/out` mounted. It runs as the account's uid, with no Linux
     capabilities, `no-new-privileges`, 3 GB of memory, 3 CPUs, and a 55
     minute cap.

   Inside the container, `agent/src/coder/main.ts`:
   - reads the issue or PR conversation from the GitHub API, which is public;
   - runs `pi --print --model $CODER_MODEL --no-approve --session-dir /out/session`,
     with Focus's rules appended to pi's system prompt. pi loads `AGENTS.md`
     by itself;
   - reads pi's answer from `/out/answer.json`: changes with a PR title, body
     and commit message, or a question;
   - runs `make check-server check-agent`. On failure it goes back to pi, in
     the same session, twice at most;
   - writes `result.json`, `changes.patch`, `transcript.html` and the
     `pi-*.log` files to `/out`.

   Back on the host, after the container has exited, `focus-coder` refuses
   the change if it touches `.github/`, `.git/`, `.secrets/` or any `.env*`.
   Otherwise it commits it as "Focus Coder" with `Refs #<issue>` and pushes
   it to the branch the workflow named, with the account's gh credentials. It
   never pushes
   to the default branch, and it refuses to even start when asked to. The push
   starts CI and E2E.

   Then `think` fetches `/out` as a tarball and uploads it as the artifact.
3. **publish** (GitHub) reads the result. For a question, it comments on the
   issue. For a pushed change, it opens the PR, or comments on the existing
   one, with this workflow's own token. If anything went wrong, it says so on
   the issue with a link to the log.

Flutter is not on the Pi, so the container cannot run `make check-app`. pi is
told that, and CI checks the app on the push.

## Why it is built this way

**The model never holds the push credential.** pi can be steered by what it
reads, issue text included. So your gh credentials stay outside the
container, and only `focus-coder` pushes: after pi has exited, after its own
path check, and only to the one branch the workflow named. The script
accepts `run` and `fetch` with strictly checked arguments.

**What your credentials can do.** They are yours, so they can do anything
you can, on every repository gh is allowed to reach. The script only ever
pushes one branch of this repository. `main` is kept safe twice: the script
refuses the default branch, and so does your ruleset, as long as its bypass
list does not include **Repository admin**. You are an admin, and a ruleset
lets admins through when that role is listed.

**Two locks on what it may change.** The container's entry point refuses a
change that touches `.github/`, `.git/`, `.secrets/` or any `.env*`, and the
host script checks the staged files again before it commits. A change to a
workflow is written by a person.

**pi runs in a box.** pi's own security guide says it runs with the
permissions of whoever starts it, and recommends a container. The container
sees the clone and the output directory and nothing else of the Pi. It holds
the OpenRouter key, so give that key a spend limit. It has network access,
because it needs OpenRouter and npm, and so it can reach the Pi's published
ports (nginx on 80). The backend and agent containers publish no ports, so
the coder cannot reach them.

**The deploy key reaches the coder.** The workflow logs in with
`PI_SSH_PRIVATE_KEY`, the key every deploy workflow already holds. It opens
a full shell on an account that runs Docker and holds your gh token, so
guard it as before.

**No GitHub App needed.** Only events caused by a workflow's own
`GITHUB_TOKEN` fail to start other workflows. A push made with your
credentials starts CI and E2E like anyone's push, and they run on `push`, not on
`pull_request`. So it does not matter that `publish` opens the PR with
`GITHUB_TOKEN`. The PR shows as opened by github-actions, and the commits as
authored by Focus Coder and pushed by you. If you ever want the Pi to hold
something narrower than your own token, a deploy key with write access works
too: set `FOCUS_CODER_PUSH_KEY` to its path.

## Setup

Merge this work to `main` first. The Pi builds the coder from `origin/main`.

### On the Raspberry Pi

Everything below runs as the user that already has `gh` and Docker, the one
the deploys log in as.

```bash
# 1. Its own clone, never ~/focus
sudo mkdir -p /opt/focus-coder && sudo chown "$USER:$USER" /opt/focus-coder
git clone https://github.com/pietroid/focus.git /opt/focus-coder/repo
mkdir -p /opt/focus-coder/bin /opt/focus-coder/runs

# 2. The script the workflow runs
install -m 755 /opt/focus-coder/repo/agent/coder/host/focus-coder /opt/focus-coder/bin/focus-coder

# 3. The model key, and nothing else
printf 'OPENROUTER_API_KEY=%s\nCODER_MODEL=%s\n' 'sk-or-...' 'openrouter/anthropic/claude-sonnet-5' \
  > /opt/focus-coder/coder.env
chmod 600 /opt/focus-coder/coder.env

# 4. Let plain git push with gh's credentials, and check them
gh auth setup-git
gh auth status
git ls-remote https://github.com/pietroid/focus.git HEAD
```

`gh auth status` must show a token that can push to this repository: the
`repo` scope for a classic token, or Contents read and write for a
fine-grained one.

`CODER_MODEL` accepts any id from `pi --list-models`. The one above is in
pi's catalog.

Re-run step 2 whenever `agent/coder/host/focus-coder` changes on `main`. The
image and the entry point rebuild on every run by themselves.

### Try it by hand

From your Mac, with the deploy key, run the coder for real on issue `<n>`.
It pushes to `agent/issue-<n>` if pi changes something:

```bash
ssh -i ~/.ssh/focus_pi <user>@<pi-ip> "/opt/focus-coder/bin/focus-coder run 1 issue <n> - main false agent/issue-<n>"
ssh -i ~/.ssh/focus_pi <user>@<pi-ip> "/opt/focus-coder/bin/focus-coder fetch 1" | tar -tz
ssh -i ~/.ssh/focus_pi <user>@<pi-ip> "/opt/focus-coder/bin/focus-coder run 2 issue <n> - main false main"   # refused: the default branch
```

### On GitHub

Nothing new. The workflow uses the secrets and variables the deploys already
have: `PI_SSH_PRIVATE_KEY`, `TUNNEL_SERVICE_TOKEN_ID`,
`TUNNEL_SERVICE_TOKEN_SECRET`, `PI_USER` and `PI_HOST`. The model key and
your GitHub credentials stay on the Pi.

### On a Pi with little memory

The image compiles only the coder's own files, which takes about 200 MB. The
checks are heavier: `make check-server` and `make check-agent` compile the
whole server and agent, including Google's API types. The container gives
Node a 2 GB heap for that, and caps the container at 3 GB. See how much you
have with `free -h`. If RAM plus swap is under about 3 GB, add swap:

```bash
sudo dphys-swapfile swapoff
sudo sed -i 's/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
sudo dphys-swapfile setup && sudo dphys-swapfile swapon
free -h
```

The knobs, in `coder.env` unless noted:

| Setting | Default | Effect |
|---|---|---|
| `NODE_OPTIONS` | `--max-old-space-size=2048` | Node's heap for pi's checks and the gate |
| `CODER_CHECKS` | `check-server check-agent` | the gate's make targets. `none` skips the gate and tells pi not to run checks, leaving them to CI |
| `FOCUS_CODER_MEMORY` (host environment) | `3g` | the container's memory cap |

## Using pi by hand

pi is also a fine editor to drive yourself. It reads `AGENTS.md` like the
coder does.

On your Mac, with Node 22.19 or newer. The repo's `.nvmrc` says 22, so
`nvm install 22` gets a new enough one:

```bash
npm install -g @earendil-works/pi-coding-agent
export OPENROUTER_API_KEY=sk-or-...
cd ~/dev/focus && pi --model openrouter/anthropic/claude-sonnet-5
```

On the Pi, in the coder's box and a scratch clone:

```bash
cd /opt/focus-coder
git clone --reference repo https://github.com/pietroid/focus.git scratch
docker run --rm -it --user "$(id -u):$(id -g)" --env-file coder.env \
  -v "$PWD/scratch:/workspace" --entrypoint pi focus-coder:latest
```

Or run the coder's whole pipeline on a prompt of your own, without an issue:

```bash
CODER_PROMPT_FILE=./prompt.md CODER_WORKSPACE=<a scratch clone> CODER_OUT=/tmp/coder \
  OPENROUTER_API_KEY=... node agent/dist/coder/main.js
```

This last one ran for real while this was built. pi took a small task in a
throwaway repository, edited the file, wrote its answer, passed the gate, and
left `changes.patch` and `transcript.html` behind. The patch applied cleanly
with `git apply --index`. The host's commit-and-push step was also run
against a local repository: a normal change landed with `Refs #<issue>`, a
change under `.github/` was refused, and a push onto a branch that had moved
on failed loudly.

## Where to look when it misbehaves

- **The `think` job's log.** pi's printed output, then `coder.pi`,
  `coder.gate` and `coder.done` lines.
- **The `coder-<run id>` artifact.** It holds `transcript.html`, the whole pi
  session, plus `result.json`, the patch and the logs, even when nothing was
  pushed.
- **On the Pi,** `/opt/focus-coder/runs/<id>/out`, kept for 7 days.
- **A comment on the issue**, whenever it asked something, gave up, failed,
  could not push, or produced a change that touched a forbidden path.
