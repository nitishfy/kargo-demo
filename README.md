# Kargo Demo

A hands-on workshop that promotes an nginx image through three stages, `test` → `uat` → `prod`, using **Kargo** and **Argo CD** on the [Akuity Platform training instance](https://training.akuity.cloud/organizations).

Please work through the **prerequisites** below **before the workshop**. Setup problems like Docker not running, a missing tool or a bad GitHub token use up most of the lab time if you leave them until the day.

---

## How the demo works

```
public.ecr.aws/nginx/nginx  ──►  Warehouse  ──►  Stage: test  ──►  Stage: uat  ──►  Stage: prod
   (new semver tags)            (Freight)           │                 │                 │
                                                     ▼                 ▼                 ▼
                                             branch stage/test  branch stage/uat  branch stage/prod
                                                     │                 │                 │
                                                     ▼                 ▼                 ▼
                                             Argo CD app        Argo CD app       Argo CD app
                                          kargo-demo-test     kargo-demo-uat    kargo-demo-prod
                                           (NodePort 30081)   (NodePort 30082)  (NodePort 30083)
```

1. The Kargo **Warehouse** watches `public.ecr.aws/nginx/nginx` for tags that match `^1.26.0`.
2. When you promote **Freight** to a Stage, Kargo:
   - clones this repo's `main` branch
   - sets the image tag in `base/` and renders `stages/<stage>` with Kustomize
   - commits the rendered manifests and **pushes** them to the `stage/<stage>` branch
   - tells Argo CD to sync the `kargo-demo-<stage>` Application to that commit
3. Argo CD deploys each stage into its own namespace (`kargo-demo-<stage>`) on your cluster.

Because Kargo **pushes commits to your Git repository**, every attendee needs their **own fork** of this repo and a **GitHub token with write access** to it.

---

## Prerequisites

### 1. Accounts

| What | Why | How to check |
|---|---|---|
| **Akuity Platform training account** | You'll create your Argo CD and Kargo instances here | Sign in at <https://training.akuity.cloud/organizations> and confirm you can see an organization |
| **GitHub account** | You need to fork this repo, and Kargo pushes to your fork | Sign in at <https://github.com> |

### 2. Tools on your laptop

| Tool | Required? | Purpose | Install |
|---|---|---|---|
| **Docker** (Docker Desktop, OrbStack, Colima, Rancher Desktop…) | ✅ Required | Runs your local Kubernetes cluster | <https://docs.docker.com/get-docker/> |
| **kind** | ✅ Required | Creates a local Kubernetes cluster | `brew install kind` or <https://kind.sigs.k8s.io/docs/user/quick-start/#installation> |
| **kubectl** | ✅ Required | Talks to the cluster and installs the Akuity agent | `brew install kubectl` or <https://kubernetes.io/docs/tasks/tools/> |
| **git** | ✅ Required | Clones your fork and pushes edits | `brew install git` or <https://git-scm.com/downloads> |
| **kargo CLI** | Optional | Lets you drive Kargo from the terminal (you can use the UI instead) | <https://github.com/akuity/kargo/releases> |
| **argocd CLI** | Optional | Lets you inspect Argo CD apps from the terminal (you can use the UI instead) | `brew install argocd` or <https://argo-cd.readthedocs.io/en/stable/cli_installation/> |
| **gh** (GitHub CLI) | Optional | Makes forking and token handling easier | `brew install gh` |

> **Windows users:** use WSL2 with Docker Desktop's WSL integration turned on, and run every command from inside your WSL shell.

### 3. Machine resources

- Docker should have at least **2 CPUs and 4 GB RAM** available. Check under *Docker Desktop → Settings → Resources*.
- Host ports **30081, 30082 and 30083** must be free. The `test`, `uat` and `prod` apps are exposed on them.
- Your laptop needs **outbound HTTPS access** to `*.akuity.cloud`, `github.com` and `public.ecr.aws`. Corporate VPNs or proxies sometimes block the Akuity agent from connecting. If you can, try the setup on the network you'll use during the workshop.

### 4. Fork this repository

1. Fork <https://github.com/nitishfy/kargo-demo> into your own GitHub account. **Keep the fork public** so Argo CD can read it without credentials.
2. Clone your fork:
   ```bash
   git clone https://github.com/<your-github-username>/kargo-demo.git
   cd kargo-demo
   ```
3. Point the manifests at your fork:
   ```bash
   ./scripts/personalize.sh
   ```
   The script reads your GitHub username from your fork's `origin` remote and rewrites the repo URL in `argocd/applicationset.yaml` and `kargo/promotion.yaml`. To set the username yourself, pass it as an argument: `./scripts/personalize.sh <your-github-username>`. You can safely re-run the script with the correct username if you made a typo.
4. Commit and push the change to `main` on your fork:
   ```bash
   git commit -am "point manifests at my fork"
   git push origin main
   ```

### 5. Create a GitHub Personal Access Token

Kargo uses this token to push the rendered manifests to the `stage/*` branches of your fork.

**Fine-grained token (recommended):** <https://github.com/settings/personal-access-tokens/new>
- **Repository access:** *Only select repositories* → your `kargo-demo` fork
- **Permissions:** *Contents* → **Read and write**
- **Expiration:** at least a few days past the workshop date

**Classic token (alternative):** <https://github.com/settings/tokens/new> with the `public_repo` scope.

Save the token somewhere safe. **You will paste it into Kargo during the workshop.** GitHub shows it only once.

### 6. Create a local cluster

Create a kind cluster that maps the stage NodePorts to your laptop, so you can open each environment in a browser:

```bash
cat <<EOF | kind create cluster --name kargo-demo --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30081   # test
    hostPort: 30081
  - containerPort: 30082   # uat
    hostPort: 30082
  - containerPort: 30083   # prod
    hostPort: 30083
EOF
```

Check it:

```bash
kubectl cluster-info --context kind-kargo-demo
kubectl get nodes          # the node should be Ready
```

> If you already have a cluster called `kargo-demo`, delete it first with `kind delete cluster --name kargo-demo`.

---

## Pre-flight checklist

Run these commands the day before the workshop. Each one should succeed:

```bash
docker info > /dev/null && echo "docker ok"
kind version
kubectl version --client
git --version
kubectl get nodes --context kind-kargo-demo
git ls-remote https://github.com/<your-github-username>/kargo-demo.git main
```

You're ready when you can tick every box:

- [ ] I can sign in to <https://training.akuity.cloud/organizations>
- [ ] I have my own **public** fork of `kargo-demo`
- [ ] My fork's `argocd/applicationset.yaml` and `kargo/promotion.yaml` point at **my** GitHub username
- [ ] I have a GitHub token with **Contents: Read and write** on my fork
- [ ] The `kind-kargo-demo` cluster is running and its node is `Ready`
- [ ] Ports 30081–30083 are free on my machine

---

## What we'll do in the workshop

You don't need to do these steps in advance. They're listed so you know what's coming.

1. Create an **Argo CD instance** on the Akuity Platform and connect your kind cluster to it by installing the Akuity agent with `kubectl`.
2. Create the Argo CD **ApplicationSet** (`argocd/applicationset.yaml`), which generates one Application per stage.
3. Create a **Kargo instance** and connect it to your Argo CD instance.
4. Apply the Kargo resources: the **Project** (`kargo/project.yaml`), **Warehouse** (`kargo/warehouse.yaml`), **PromotionTask** and **Stages** (`kargo/promotion.yaml`).
5. Add your **GitHub token** as a Git credential in the `kargo-demo` Kargo project.
6. Promote Freight through `test` → `uat` → `prod` and watch the apps at:
   - test: <http://localhost:30081>
   - uat: <http://localhost:30082>
   - prod: <http://localhost:30083>

---

## Repository layout

```
.
├── argocd/
│   └── applicationset.yaml   # One Argo CD Application per stage, tracking branch stage/<stage>
├── base/                     # Shared nginx Deployment + NodePort Service
├── scripts/
│   └── personalize.sh        # Points the manifests at your fork
├── stages/
│   ├── test/                 # Stage-specific page content + NodePort 30081
│   ├── uat/                  # Stage-specific page content + NodePort 30082
│   └── prod/                 # Stage-specific page content + NodePort 30083
└── kargo/
    ├── project.yaml          # Kargo Project
    ├── warehouse.yaml        # Subscribes to public.ecr.aws/nginx/nginx (^1.26.0)
    └── promotion.yaml        # PromotionTask + test/uat/prod Stages
```

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `kind create cluster` fails with `port is already allocated` | Something else is using port 30081–30083. Stop that process, or delete an old kind cluster. |
| Akuity agent pods stay in `CrashLoopBackOff` or never connect | Usually a network issue: a VPN, proxy or firewall is blocking outbound traffic to `*.akuity.cloud`. Try another network. |
| Promotion fails at `git-push` with `403` / `authentication required` | Either your GitHub token is missing, expired, or lacks *Contents: Read and write* on your fork, or the manifests still point at `nitishfy/kargo-demo` instead of your fork. Run `./scripts/personalize.sh`, then commit and push. |
| `personalize.sh` says the clone points at `nitishfy/kargo-demo` | You cloned the original repo instead of your fork. Clone your fork, or run `./scripts/personalize.sh <your-github-username>`. |
| Argo CD app shows `repository not found` | Your fork is private, or `argocd/applicationset.yaml` still has the wrong `repoURL`. |
| Warehouse shows no Freight | Wait a minute for discovery, then use **Refresh** on the Warehouse in the Kargo UI. |
