# Compute cluster plan

The Raspberry Pi and the Mac become one k3s cluster joined over Tailscale. The
cluster places each workload on the right machine by itself, and GitHub only
delivers events.

## Goal

What it has to run:

1. Server, app and agent serving, up at all times.
2. Coding runs with pi.dev or opencode.
3. E2E test runs.
4. Later, local LLMs.

How it should work: GitHub is a thin layer or absent. One self-managed system
decides where things run. It is open source, needs little custom scripting, and
uses the mainstream ecosystem so the skills carry over to real Kubernetes work.

## The stack

| Piece | Job | Why this one |
|---|---|---|
| [Tailscale](https://tailscale.com) | Private network between the Pi, the Mac and anything else | Works from any network with no port forwarding. k3s joins nodes over it with `--vpn-auth` |
| [k3s](https://k3s.io) | Kubernetes: schedules, restarts and moves workloads | Real Kubernetes in one small binary, built for ARM boards like the Pi |
| [Argo CD](https://argo-cd.readthedocs.io) | GitOps: applies the manifests on `main` to the cluster | A merge is a deploy, with no deploy workflow |
| [Actions Runner Controller](https://github.com/actions/actions-runner-controller) (ARC) | Runs GitHub runners as pods inside the cluster | GitHub delivers the event, the work runs on your machines with no SSH hop |
| [Colima](https://github.com/abiosoft/colima) | Linux VM on the Mac that hosts its k3s agent | Kubernetes nodes are Linux, and macOS isn't |
| [Ollama](https://ollama.com) | Local LLM serving, native on macOS | Uses the Mac's GPU through Metal, which a VM can't reach |

If GitHub should go away entirely later,
[Argo Events](https://argoproj.github.io/argo-events/) triggers cluster jobs
from webhooks directly, and ARC goes away.

## Where each workload runs

```
┌─ Raspberry Pi · k3s server ─────┐    ┌─ Mac ───────────────────────────┐
│  label role=always-on           │    │  ┌─ Colima VM · k3s agent ────┐ │
│                                 │    │  │  label role=burst          │ │
│  Control plane                  │    │  │                            │ │
│    k3s API, Argo CD, ARC        │    │  │  Coder Jobs (pi.dev)       │ │
│                                 │    │  │  E2E Jobs                  │ │
│  Server, app, agent             │    │  └────────────┬───────────────┘ │
│    Deployments, always up  ─────┼────┼──► Ollama, native on macOS     │
│                                 │    │               │                │
│  Fallback: coder and E2E  ◄─────┼────┼── when the Mac sleeps          │
└─────────────────────────────────┘    └─────────────────────────────────┘
                       Tailscale joins both, from any network
```

| Workload | Kubernetes object | Placement |
|---|---|---|
| server, app, agent | Deployment | `nodeSelector: {role: always-on}`, Pi only |
| coder | Job, through ARC | preferred affinity for `role=burst`, falls back to the Pi |
| E2E | Job, through ARC | preferred affinity for `role=burst`, falls back to the Pi |
| local LLM | native Ollama, `ExternalName` Service in the cluster | Mac only |

## Known limits

| Limit | What it means | Mitigation |
|---|---|---|
| Some YAML to write | A Deployment and a Service per service, plus a Job template for the coder and E2E | Declarative config, not scripts. `agent/coder/Dockerfile` carries over unchanged |
| The Mac needs a VM | Kubernetes nodes are Linux, so the Mac's k3s agent runs inside Colima | Give Colima a fixed CPU and memory size and start it at login |
| No GPU inside the VM | Local LLMs can't run as cluster pods on the Mac | Run Ollama natively and point a Service at it |
| Pi RAM is tight | Control plane, server, agent and a fallback 3 GB coder job at once is tight on 8 GB and won't fit on 4 GB | Requests and limits on everything, so a fallback job waits instead of starving the server |
| The Mac sleeps | Jobs on the Mac die when it sleeps, then get retried on the Pi | Keep the Mac awake on power. Set a retry count on the Jobs |

Tailscale's clients are open source but its coordination server isn't.
[Headscale](https://github.com/juanfont/headscale) replaces it if that matters
later.

## Build order

Six phases. Each one leaves a working system, so you can stop after any of
them. Check the commands against each project's current docs before running.

### 1. Pi becomes the control plane

Raspberry Pi OS needs `cgroup_memory=1 cgroup_enable=memory` appended to
`/boot/firmware/cmdline.txt`, then a reboot.

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --vpn-auth=name=tailscale,joinKey=<tailscale-auth-key> --node-label role=always-on" sh -
```

Copy `/etc/rancher/k3s/k3s.yaml` to `~/.kube/config` on the Mac and point its
`server:` at the Pi's Tailscale name. Approve the pod network routes in the
Tailscale admin console, as the k3s Tailscale docs describe.

**Done when** `kubectl get nodes` on the Mac shows the Pi as Ready.

### 2. Server, app and agent move into the cluster

Build arm64 images and push them to GHCR. Write a Deployment and a Service for
each, pinned with `nodeSelector: {role: always-on}`, with requests and limits
on every one. k3s ships Traefik as the ingress. Run `cloudflared` as a
Deployment so public traffic keeps coming through the existing Cloudflare
tunnel.

**Done when** the public URL is served by the pods and the old deploy on the Pi
is off.

### 3. Argo CD deploys from git

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Keep the manifests in the repo, for example under `deploy/k8s/`, and create one
Argo CD Application that watches that folder on `main`.
[Argo CD Image Updater](https://argocd-image-updater.readthedocs.io) can bump
image tags when CI pushes a new image.

**Done when** merging a manifest change rolls it out with no workflow involved.

### 4. The Mac joins as a worker

```bash
brew install colima
colima start --cpu <n> --memory <gb>
colima ssh
```

Inside the VM, install Tailscale the same way, then the k3s agent. The join
token is in `/var/lib/rancher/k3s/server/node-token` on the Pi.

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://<pi-tailscale-name>:6443 K3S_TOKEN=<token> INSTALL_K3S_EXEC="agent --vpn-auth=name=tailscale,joinKey=<tailscale-auth-key> --node-label role=burst" sh -
```

**Done when** `kubectl get nodes` shows both machines Ready, and the Mac drops
to NotReady when it sleeps and comes back when it wakes.

### 5. Coder and E2E run through ARC

Install the ARC controller and one runner scale set with Helm, authenticated
with a GitHub App. Use `containerMode.type=dind`, since the coder builds and
runs its own image. Give the runner pods a preferred node affinity for
`role=burst`. The Pi account's GitHub credentials move into a Kubernetes
Secret.

```bash
helm install arc --namespace arc-systems --create-namespace oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
helm install focus-runners --namespace arc-runners --create-namespace -f runners.yaml oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

In `coder.yml` and the E2E workflow, the heavy job becomes
`runs-on: focus-runners`.

**Done when** labelling an issue `agent` runs the coder on the Mac, and on the
Pi when the Mac is asleep.

### 6. Local LLMs on the Mac

Install Ollama natively and make it listen on the Tailscale interface. In the
cluster, an `ExternalName` Service named `ollama` points at the Mac's Tailscale
name, so pods reach it at `ollama:11434`.

```bash
brew install ollama
OLLAMA_HOST=0.0.0.0 ollama serve
```

**Done when** a pod lists the Mac's models with
`curl http://ollama:11434/api/tags`.

## What goes away

Today the `think` job in `.github/workflows/coder.yml` runs on a GitHub runner
and reaches the Pi over SSH through the Cloudflare Access tunnel. After phase 5
it runs inside the cluster.

| Today | After |
|---|---|
| `pi-ssh` action, `PI_SSH_PRIVATE_KEY`, `TUNNEL_SERVICE_TOKEN_*` secrets | Runner pod already inside the cluster, no SSH |
| `focus-coder fetch` piping a tarball back to GitHub | The job uploads its artifact directly |
| `agent/coder/host/focus-coder` installed by hand in `/opt/focus-coder/bin/` | Job steps in the workflow, same `focus-coder` image |
| `pi-connect.sh` for SSH from the Mac | `kubectl` over Tailscale, or `ssh` to the Pi's Tailscale name |
| Manual deploys on the Pi | Argo CD applying `main` |

The rules stay: the image is built from `origin/main`, a change can't touch
`.github/`, `.git/`, `.secrets/` or `.env*`, and pushes never go to the default
branch.
