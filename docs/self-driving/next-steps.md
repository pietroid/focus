# Next steps after the merge

What is left once the self-driving work is on `main`: set the coder up on the
Raspberry Pi, give GitHub what it needs, and run the loop once.

Everything on the Pi runs as the same user the deploys log in as. The
coder workflow reaches the Pi the way the deploys do, with
`PI_SSH_PRIVATE_KEY` through the Cloudflare tunnel, so GitHub needs no new
secret.

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
   After the coder script changes on `main`, refresh it the same way:
   ```bash
   git -C /opt/focus-coder/repo pull
   install -m 755 /opt/focus-coder/repo/agent/coder/host/focus-coder /opt/focus-coder/bin/focus-coder
   ```

3. **Save the model key**, readable only by you. Give that OpenRouter key a
   spend limit.
   ```bash
   printf 'OPENROUTER_API_KEY=%s\nCODER_MODEL=%s\n' 'sk-or-...' 'openrouter/moonshotai/kimi-k2.7-code' > /opt/focus-coder/coder.env
   chmod 600 /opt/focus-coder/coder.env
   ```
   `CODER_MODEL` takes any id from `pi --list-models`. Changing it needs no
   redeploy; the next run picks it up.

4. **Log git in to GitHub and check it can push.** If `gh auth login` is
   already done, run `gh auth setup-git` once so plain `git push` uses it. A
   dry run authenticates like a real push and changes nothing.
   ```bash
   gh auth status
   cd /opt/focus-coder/repo
   git push --dry-run https://github.com/pietroid/focus.git HEAD:refs/heads/coder-push-test
   ```

5. **Build the coder's image once.** Every run rebuilds it anyway, but the
   first build on a Pi takes several minutes, and a problem is better found
   now.
   ```bash
   git -C /opt/focus-coder/repo archive origin/main:agent | docker build -t focus-coder -f coder/Dockerfile -
   ```

## On GitHub

6. **Create the label.** Go to **Issues → Labels → New label → `agent`**.

7. **Protect `main`.**
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

8. Open a small issue, for example "Rename the Coisas heading to Minhas
    coisas", and label it `agent`. To run it again later, remove the label
    and add it back. You should get a question on the issue, or a PR. CI and
    E2E run on its branch, and the video is linked on the PR when E2E
    finishes.

The full background is in [04-coder.md](04-coder.md) and
[README.md](README.md).
