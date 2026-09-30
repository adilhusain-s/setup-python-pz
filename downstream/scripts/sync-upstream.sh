#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

SKIP_FETCH=0
UPSTREAM_REF="upstream/main"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-fetch)
      SKIP_FETCH=1
      shift
      ;;
    *)
      UPSTREAM_REF="$1"
      shift
      ;;
  esac
done

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: working tree must be clean before syncing."
  exit 1
fi

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "==> Remote 'upstream' not found; adding https://github.com/actions/setup-python.git"
  git remote add upstream https://github.com/actions/setup-python.git
fi

UPSTREAM_URL="$(git remote get-url upstream)"
NORMALIZED_URL="${UPSTREAM_URL%.git}"
if [[ "$NORMALIZED_URL" != "https://github.com/actions/setup-python" && \
      "$NORMALIZED_URL" != "git@github.com:actions/setup-python" ]]; then
  echo "ERROR: remote 'upstream' points to unexpected URL: '$UPSTREAM_URL' (expected https://github.com/actions/setup-python.git)."
  exit 1
fi

if [[ "$SKIP_FETCH" -eq 0 && "${SYNC_SKIP_FETCH:-0}" != "1" ]]; then
  echo "==> Fetching latest upstream"
  git fetch upstream main
fi

git rev-parse --verify "$UPSTREAM_REF" >/dev/null 2>&1 || {
  echo "ERROR: upstream ref '$UPSTREAM_REF' does not exist."
  exit 1
}

UPSTREAM_SHA="$(git rev-parse "$UPSTREAM_REF")"

UPSTREAM_PATHS=(
  src
  __tests__
  action.yml
  package.json
  package-lock.json
)

echo "==> Restoring upstream-owned files from $UPSTREAM_REF"
git checkout "$UPSTREAM_REF" -- "${UPSTREAM_PATHS[@]}"

CONFIG_PATHS=(
  tsconfig.json
  jest.config.js
  jest.config.ts
  .eslintrc.js
  eslint.config.mjs
  .eslintignore
  .prettierrc.js
  .prettierrc.json
  .prettierignore
)

echo "==> Synchronizing upstream configuration files"
for path in "${CONFIG_PATHS[@]}"; do
  if git cat-file -e "$UPSTREAM_REF:$path" 2>/dev/null; then
    git checkout "$UPSTREAM_REF" -- "$path"
  else
    git rm -f --ignore-unmatch -- "$path"
  fi
done

echo "==> Applying downstream patches"
while IFS= read -r patch; do
  [[ -z "$patch" ]] && continue
  [[ "$patch" =~ ^# ]] && continue

  echo "    $patch"
  if ! git apply --3way "downstream/patches/$patch"; then
    echo "ERROR: Patch '$patch' failed to apply. Stopping sync immediately."
    exit 1
  fi
done < downstream/patches/series

echo "==> Validating"
"$ROOT/downstream/scripts/validate.sh"

printf '%s\n%s\n' \
  'actions/setup-python' \
  "$UPSTREAM_SHA" \
  > downstream/UPSTREAM_VERSION

echo
echo "==> Sync complete"
echo "Upstream: $UPSTREAM_REF"
echo "SHA:      $UPSTREAM_SHA"

git status --short
