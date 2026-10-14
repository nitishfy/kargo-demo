# Kargo Demo

In this workshop you'll use **Kargo** and **Argo CD** on the [Akuity Platform training instance](https://training.akuity.cloud/organizations) to promote an nginx image through `test` → `uat` → `prod`.

Please finish the setup below **before the workshop**.

## Prerequisites

**Knowledge**
- Basic Kubernetes: Pods, Deployments, Services, Namespaces, and running `kubectl get` / `kubectl apply`
- Basic Git and GitHub: clone, commit, push, fork and branches
- Comfortable reading YAML and using a Linux terminal (bash)
- Helpful but not required: a general idea of GitOps and Argo CD. No prior Kargo experience is needed.

**Laptop (Windows)**
- Windows 10 (22H2) or Windows 11
- 16 GB RAM recommended (8 GB minimum)
- Hardware virtualization enabled. Check *Task Manager → Performance → CPU → Virtualization: Enabled*.
- **Admin rights** to install WSL2 and Docker Desktop. If you don't have them, ask IT to install both before the workshop.
- Ports 30081–30083 free
- Outbound HTTPS access to `*.akuity.cloud`, `github.com` and `public.ecr.aws`. Check that your corporate VPN or proxy allows it.

**Accounts**
- Akuity Platform training account. Check that you can sign in at <https://training.akuity.cloud/organizations>.
- A personal or work GitHub account that is allowed to fork public repos and create Personal Access Tokens. Some company GitHub organizations block these.

**Tools**
- [WSL2](https://learn.microsoft.com/windows/wsl/install) with Ubuntu. **Run every command in this guide from the Ubuntu (WSL) terminal**, not PowerShell or CMD.
- [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/) with WSL integration turned on. Docker Desktop needs a paid subscription at companies with more than 250 employees or more than $10M in annual revenue. [Rancher Desktop](https://rancherdesktop.io/) is a free alternative; select the `dockerd (moby)` engine and turn on WSL integration.
- kind, kubectl and git, installed inside WSL (see step 1 below)
- A web browser and a code editor. VS Code with the [WSL extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl) works well.

## Setup

### 1. Install WSL, Docker and the CLI tools

1. In **PowerShell as Administrator**, install WSL with Ubuntu, then restart your laptop:
   ```powershell
   wsl --install -d Ubuntu
   ```
2. Install Docker Desktop. Go to *Settings → Resources → WSL integration* and turn it on for **Ubuntu**.
3. Open the **Ubuntu** terminal and install git, kubectl and kind:
   ```bash
   sudo apt-get update && sudo apt-get install -y git curl
   ARCH=$(dpkg --print-architecture)
   curl -Lo kubectl "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
   curl -Lo kind "https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-linux-${ARCH}"
   sudo install -m 0755 kubectl kind /usr/local/bin/ && rm kubectl kind
   ```
4. Check that everything works:
   ```bash
   docker run --rm hello-world
   kubectl version --client
   kind version
   ```

### 2. Fork and personalize the repo

Kargo pushes commits to the repo during promotions, so you need your own fork.

1. Fork <https://github.com/nitishfy/kargo-demo>. Keep the fork **public**.
2. In the Ubuntu terminal, clone your fork into your **WSL home directory** (not `C:\` or `/mnt/c`), point the manifests at it, and push:
   ```bash
   cd ~
   git clone https://github.com/<your-github-username>/kargo-demo.git
   cd kargo-demo
   ./scripts/personalize.sh
   git commit -am "point manifests at my fork"
   git push origin main
   ```
   When `git push` asks for a password, paste the GitHub token from step 3. GitHub doesn't accept account passwords over HTTPS.

### 3. Create a GitHub token

Create a [fine-grained token](https://github.com/settings/personal-access-tokens/new) that gives your `kargo-demo` fork **Contents: Read and write** access. Save the token somewhere safe, because you'll also paste it into Kargo during the workshop.

### 4. Create a local cluster

Run this in the Ubuntu terminal, with Docker Desktop running:

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

kubectl get nodes   # should show Ready
```

During the workshop you'll connect this cluster to your Argo CD instance. Name it **`kargo-demo`**, because the ApplicationSet deploys to a cluster with that name. You'll open the stages in your Windows browser at `http://localhost:30081`, `30082` and `30083`.

## Checklist

- [ ] I can sign in to the Akuity training instance
- [ ] `docker run --rm hello-world` works in the Ubuntu (WSL) terminal
- [ ] I have a public fork, and `./scripts/personalize.sh` changes are pushed to it
- [ ] I have a GitHub token with Contents: Read and write on my fork
- [ ] `kubectl get nodes` shows the `kargo-demo` kind cluster as `Ready`

## Repository layout

```
.
├── argocd/
│   └── applicationset.yaml   # One Argo CD Application per stage, tracking branch stage/<stage>
├── base/                     # Shared nginx Deployment + NodePort Service
├── kargo/
│   ├── project.yaml          # Kargo Project
│   ├── warehouse.yaml        # Subscribes to public.ecr.aws/nginx/nginx (^1.26.0)
│   └── promotion.yaml        # PromotionTask + test/uat/prod Stages
├── scripts/
│   └── personalize.sh        # Points the manifests at your fork
└── stages/
    ├── test/                 # Stage page content + NodePort 30081
    ├── uat/                  # Stage page content + NodePort 30082
    └── prod/                 # Stage page content + NodePort 30083
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `wsl --install` fails, or Docker says virtualization is not enabled | Turn on virtualization (Intel VT-x / AMD-V) in BIOS/UEFI, or ask IT to do it. |
| `docker: command not found` or `Cannot connect to the Docker daemon` in WSL | Start Docker Desktop, and check that *Settings → Resources → WSL integration* is on for Ubuntu. |
| `personalize.sh` fails with `bash\r: No such file or directory` | You cloned the repo with Git for Windows. Clone it again from the Ubuntu terminal into `~`. |
| `kind create cluster` fails with `port is already allocated` | Free ports 30081–30083, or delete the old cluster with `kind delete cluster --name kargo-demo`. |
| `personalize.sh` says the clone points at `nitishfy/kargo-demo` | You cloned the original repo, not your fork. Clone your fork, or run `./scripts/personalize.sh <your-github-username>`. |
| Akuity agent never connects | A VPN, proxy or firewall is likely blocking `*.akuity.cloud`. Try another network. |
| Promotion fails at `git-push` with `403` | Your token is missing, has expired or lacks Contents: Read and write, or you didn't push the `personalize.sh` changes. |
| Argo CD app shows `cluster 'kargo-demo' not found` | The cluster you connected in Akuity has a different name. Reconnect it as `kargo-demo`, or change `destination.name` in `argocd/applicationset.yaml`. |
| Argo CD app shows `repository not found` | Your fork is private, or the `personalize.sh` changes weren't pushed. |
| Warehouse shows no Freight | Wait a minute, then click **Refresh** on the Warehouse in the Kargo UI. |
