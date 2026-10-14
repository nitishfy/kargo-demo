# Kargo Demo

In this workshop you'll use **Kargo** and **Argo CD** on the [Akuity Platform training instance](https://training.akuity.cloud/organizations) to promote an nginx image through `test` → `uat` → `prod`.

Please finish the setup below **before the workshop**.

## Prerequisites

**Accounts**
- Akuity Platform training account. Check that you can sign in at <https://training.akuity.cloud/organizations>.
- GitHub account

**Tools**
- [Docker](https://docs.docker.com/get-docker/) with at least 2 CPUs and 4 GB RAM
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- git

Windows users: use WSL2 and run every command from inside WSL.

## Setup

### 1. Fork and personalize the repo

Kargo pushes commits to the repo during promotions, so you need your own fork.

1. Fork <https://github.com/nitishfy/kargo-demo>. Keep the fork **public**.
2. Clone your fork, point the manifests at it, and push:
   ```bash
   git clone https://github.com/<your-github-username>/kargo-demo.git
   cd kargo-demo
   ./scripts/personalize.sh
   git commit -am "point manifests at my fork"
   git push origin main
   ```

### 2. Create a GitHub token

Create a [fine-grained token](https://github.com/settings/personal-access-tokens/new) that gives your `kargo-demo` fork **Contents: Read and write** access. Save the token somewhere safe, because you'll paste it into Kargo during the workshop.

### 3. Create a local cluster

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

During the workshop you'll connect this cluster to your Argo CD instance. Name it **`kargo-demo`**, because the ApplicationSet deploys to a cluster with that name.

## Checklist

- [ ] I can sign in to the Akuity training instance
- [ ] I have a public fork, and `./scripts/personalize.sh` changes are pushed to it
- [ ] I have a GitHub token with Contents: Read and write on my fork
- [ ] `kubectl get nodes` shows the `kargo-demo` kind cluster as `Ready`

> If you're on a corporate VPN or proxy, make sure it allows outbound access to `*.akuity.cloud`, `github.com` and `public.ecr.aws`.

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
| `kind create cluster` fails with `port is already allocated` | Free ports 30081–30083, or delete the old cluster with `kind delete cluster --name kargo-demo`. |
| `personalize.sh` says the clone points at `nitishfy/kargo-demo` | You cloned the original repo, not your fork. Clone your fork, or run `./scripts/personalize.sh <your-github-username>`. |
| Akuity agent never connects | A VPN, proxy or firewall is likely blocking `*.akuity.cloud`. Try another network. |
| Promotion fails at `git-push` with `403` | Your token is missing, has expired or lacks Contents: Read and write, or you didn't push the `personalize.sh` changes. |
| Argo CD app shows `cluster 'kargo-demo' not found` | The cluster you connected in Akuity has a different name. Reconnect it as `kargo-demo`, or change `destination.name` in `argocd/applicationset.yaml`. |
| Argo CD app shows `repository not found` | Your fork is private, or the `personalize.sh` changes weren't pushed. |
| Warehouse shows no Freight | Wait a minute, then click **Refresh** on the Warehouse in the Kargo UI. |
