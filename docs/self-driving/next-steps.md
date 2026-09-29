# Next steps after the merge

What is left once the self-driving work is on `main`: set the coder up on the
Raspberry Pi, give GitHub what it needs, and run the loop once.

Everything on the Pi runs as the same user the deploys log in as.

## On the Raspberry Pi

1. **Check the basics.** This user needs Docker without `sudo`, and git.
   ```bash
   docker ps > /dev/null && echo "docker ok"
   git --version
   ```

2. **Give the coder its own folder and clone.** It is separate from `~/focus`,
   the checkout the deploys use.
   ```bash
   sudo mkdir -p /opt/focus-coder && sudo chown "$USER:$USER" /opt/focus-coder
   git clone https://github.com/pietroid/focus.git /opt/focus-coder/repo
   mkdir -p /opt/focus-coder/bin /opt/focus-coder/runs
   install -m 755 /opt/focus-coder/repo/agent/coder/host/focus-coder /opt/focus-coder/bin/focus-coder
   ```

3. **Save the model key**, readable only by you. Give that OpenRouter key a
   spend limit.
   ```bash
   printf 'OPENROUTER_API_KEY=%s\nCODER_MODEL=%s\n' 'sk-or-...' 'openrouter/anthropic/claude-sonnet-5' > /opt/focus-coder/coder.env
   chmod 600 /opt/focus-coder/coder.env
   ```

4. **Check that git can push with your GitHub account.** A dry run
   authenticates like a real push and changes nothing.
   ```bash
   cd /opt/focus-coder/repo
   git push --dry-run https://github.com/pietroid/focus.git HEAD:refs/heads/coder-push-test
   ```
   If it asks for a username or fails, run `gh auth setup-git` once and try
   again.

5. **Build the coder's image once.** Every run rebuilds it anyway, but the
   first build on a Pi takes several minutes, and a problem is better found
   now.
   ```bash
   git -C /opt/focus-coder/repo archive origin/main:agent | docker build -t focus-coder -f coder/Dockerfile -
   ```

## The key GitHub uses to reach the Pi

Steps 6 to 8 are optional. Without `CODER_SSH_PRIVATE_KEY`, the coder
workflow logs in with the deploy key (`PI_SSH_PRIVATE_KEY`), which already
works. A key of its own is narrower: it can run the coder script and nothing
else, while the deploy key opens a full shell.

6. **On your Mac:**
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/focus_coder -N "" -C "focus-coder"
   cat ~/.ssh/focus_coder.pub
   ```

7. **On the Pi**, add one line to `~/.ssh/authorized_keys`, with your public
   key pasted in. The `command=` part locks this key to the coder script.
   ```
   command="/opt/focus-coder/bin/focus-coder",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ssh-ed25519 AAAA...your key... focus-coder
   ```

8. **Test from your Mac** on the local network, with a real issue number
   `<n>`:
   ```bash
   ssh -i ~/.ssh/focus_coder <user>@<pi-ip> "run 1 issue <n> - main false agent/issue-<n>"
   ssh -i ~/.ssh/focus_coder <user>@<pi-ip> "bash"
   ```
   The first runs pi, and pushes `agent/issue-<n>` if it changed something.
   The second must be refused.

## On GitHub

9. **Add the key and the label.** Under **Settings → Secrets and variables →
   Actions**, add the secret `CODER_SSH_PRIVATE_KEY` with the whole
   `~/.ssh/focus_coder` file. Then create the issue label `agent`.

10. **Protect `main`.**
    - Create a `production` environment under **Settings → Environments**.
    - Add a branch ruleset on `main` under **Settings → Rules**. Require a
      pull request and the checks `server`, `agent`, `app` and `e2e`, and
      block force pushes and deletions.
    - Leave the ruleset's bypass list empty. Do not add Repository admin,
      because the Pi pushes as you.

## One thing to check on production

The dev environment commit moves the agent's default port from 3001 to 3002,
and the deploy workflows roll that out on the Pi. Whether the backend still
reaches the agent depends on `PORT` in `agent/.env.production` and
`AGENT_URL` in `server/.env.production` on the Pi. After the deploy, send one
chat message in the app. If it answers "could not reach my brain", make those
two values agree on the same port.

## Try the whole loop

11. Open a small issue, for example "Rename the Coisas heading to Minhas
    coisas", and label it `agent`. You should get a question on the issue, or
    a PR. CI and E2E run on its branch, and the video is linked on the PR
    when E2E finishes.

The full background is in [04-coder.md](04-coder.md) and
[README.md](README.md).
