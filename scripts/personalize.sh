#!/usr/bin/env bash
#
# Points the manifests in this repo at your fork of kargo-demo.
#
# Usage:
#   ./scripts/personalize.sh                    # detect username from the 'origin' remote
#   ./scripts/personalize.sh <github-username>  # or pass it explicitly
#
# Safe to re-run: it rewrites any github.com/<user>/kargo-demo URL, so it also
# fixes a typo from a previous run.

set -euo pipefail

UPSTREAM_OWNER="nitishfy"
REPO_NAME="kargo-demo"

cd "$(git rev-parse --show-toplevel)"

username="${1:-}"

if [[ -z "$username" ]]; then
  origin_url="$(git remote get-url origin 2>/dev/null || true)"
  # Handles https://github.com/<user>/kargo-demo(.git) and git@github.com:<user>/kargo-demo(.git)
  if [[ "$origin_url" =~ github\.com[:/]([^/]+)/${REPO_NAME}(\.git)?/?$ ]]; then
    username="${BASH_REMATCH[1]}"
  fi
fi

if [[ -z "$username" ]]; then
  read -r -p "GitHub username: " username
fi

if [[ ! "$username" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]]; then
  echo "error: '$username' is not a valid GitHub username" >&2
  exit 1
fi

if [[ "$username" == "$UPSTREAM_OWNER" ]]; then
  echo "error: this clone points at ${UPSTREAM_OWNER}/${REPO_NAME}, not your fork." >&2
  echo "       Fork https://github.com/${UPSTREAM_OWNER}/${REPO_NAME}, clone your fork," >&2
  echo "       then re-run this script (or pass your username explicitly)." >&2
  exit 1
fi

pattern="github\.com/[A-Za-z0-9-]+/${REPO_NAME}"
replacement="github.com/${username}/${REPO_NAME}"

files=()
while IFS= read -r f; do
  files+=("$f")
done < <(grep -rlE "$pattern" --include='*.yaml' --exclude-dir=.git . || true)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "error: no manifests reference github.com/<user>/${REPO_NAME}" >&2
  exit 1
fi

for f in "${files[@]}"; do
  # -i.bak works with both BSD (macOS) and GNU sed
  sed -E -i.bak "s#${pattern}#${replacement}#g" "$f"
  rm -f "$f.bak"
  echo "updated ${f#./}"
done

if git diff --quiet -- "${files[@]}"; then
  echo
  echo "Manifests already point at ${replacement}. Nothing to change."
  exit 0
fi

echo
git --no-pager diff --stat -- "${files[@]}"
echo
echo "Done. Commit and push the change to your fork:"
echo
echo "  git commit -am \"point manifests at ${username}/${REPO_NAME}\""
echo "  git push origin main"
