#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

SERIES_FILE="$ROOT/downstream/patches/series"
if [[ ! -f "$SERIES_FILE" ]]; then
  echo "ERROR: series file not found at $SERIES_FILE"
  exit 1
fi

echo "==> Verifying patch series integrity"
declare -A listed_patches
while IFS= read -r patch; do
  [[ -z "$patch" ]] && continue
  [[ "$patch" =~ ^# ]] && continue

  if [[ ! -f "$ROOT/downstream/patches/$patch" ]]; then
    echo "ERROR: patch '$patch' listed in series does not exist on disk."
    exit 1
  fi
  listed_patches["$patch"]=1
done < "$SERIES_FILE"

echo "==> Detecting unlisted patch files"
unlisted_found=0
for patch_path in "$ROOT"/downstream/patches/*.patch; do
  [[ -e "$patch_path" ]] || continue
  patch_name="$(basename "$patch_path")"
  if [[ -z "${listed_patches[$patch_name]:-}" ]]; then
    echo "ERROR: unlisted patch file found: $patch_name (not in series)."
    unlisted_found=1
  fi
done
if [[ "$unlisted_found" -ne 0 ]]; then
  exit 1
fi

echo "==> Syntax-checking shell scripts"
for script in "$ROOT"/downstream/scripts/*.sh; do
  [[ -e "$script" ]] || continue
  echo "    Checking $(basename "$script")"
  bash -n "$script"
done

# Resolve IBM main ref
IBM_REF="${1:-}"
if [[ -z "$IBM_REF" ]]; then
  for candidate in ibm/main remotes/ibm/main ibm-main origin/ibm-main; do
    if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
      IBM_REF="$candidate"
      break
    fi
  done
fi

if [[ -z "$IBM_REF" ]] || ! git rev-parse --verify "$IBM_REF" >/dev/null 2>&1; then
  echo "ERROR: could not resolve IBM main ref (tried ibm/main)."
  exit 1
fi

echo "==> Using IBM base ref: $IBM_REF ($(git rev-parse --short "$IBM_REF"))"

WORKTREE_DIR="$(mktemp -d -t setup-python-check-patches.XXXXXX)"
echo "==> Creating disposable worktree at $WORKTREE_DIR"

cleanup() {
  echo "==> Cleaning up disposable worktree"
  if [[ -n "${WORKTREE_DIR:-}" && -d "$WORKTREE_DIR" ]]; then
    git worktree remove --force "$WORKTREE_DIR" 2>/dev/null || rm -rf "$WORKTREE_DIR"
    git worktree prune 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

git worktree add --detach "$WORKTREE_DIR" "$IBM_REF"

echo "==> Staging downstream framework in worktree"
cp -r "$ROOT/downstream" "$WORKTREE_DIR/downstream"

(
  cd "$WORKTREE_DIR"
  git add downstream
  git commit -m "chore: temporary downstream commit for patch testing" --quiet

  echo "==> Running sync-upstream.sh inside worktree"
  ./downstream/scripts/sync-upstream.sh

  echo "==> Verifying IBM marker: IBM/python-versions-pz"
  grep -q "IBM/python-versions-pz" action.yml || {
    echo "ERROR: Marker 'IBM/python-versions-pz' missing from action.yml"
    exit 1
  }
  grep -q "python-versions-pz" src/install-python.ts || {
    echo "ERROR: Marker 'python-versions-pz' missing from src/install-python.ts"
    exit 1
  }
  grep -q "DEFAULT_REPO_OWNER = 'IBM'" src/install-python.ts || {
    echo "ERROR: Marker \"DEFAULT_REPO_OWNER = 'IBM'\" missing from src/install-python.ts"
    exit 1
  }

  echo "==> Verifying IBM marker: ppc64le normalization"
  grep -q "ppc64le" src/setup-python.ts || {
    echo "ERROR: Marker 'ppc64le' missing from src/setup-python.ts"
    exit 1
  }

  echo "==> Verifying security audit"
  npm audit --audit-level=high
  npm audit --omit=dev --audit-level=high

  echo "==> Verifying package.json upstream identity"
  UPSTREAM_SHA="$(sed -n '2p' downstream/UPSTREAM_VERSION)"
  git diff --exit-code "$UPSTREAM_SHA" -- package.json || {
    echo "ERROR: package.json has deviated from upstream revision '$UPSTREAM_SHA'"
    exit 1
  }
)

echo "==> check-patches completed successfully!"
