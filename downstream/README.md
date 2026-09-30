# Downstream Sync Framework: Ownership & Acceptance

This directory contains the downstream maintenance machinery, patch series, and synchronization automation for IBM's Power and zSystems (`setup-python-pz`) fork of GitHub's [`actions/setup-python`](https://github.com/actions/setup-python).

---

## Directory Layout

```text
downstream/
  README.md
  UPSTREAM_VERSION

  patches/
    series
    0001-ibm-python-versions-pz.patch
    0002-ppc64le-normalization.patch
    0003-ibm-secret-scan-allowlist.patch
    0004-dependency-cve-fixes.patch

  scripts/
    sync-upstream.sh
    validate.sh
    check-patches.sh
```

---

## Responsibilities & Script Contracts

| Script | Mutates Tree? | Fetches Upstream? | Builds? | Purpose |
|---|:---:|:---:|:---:|---|
| `sync-upstream.sh` | Yes | Yes | Yes (via `validate.sh`) | Reconstructs and synchronizes the downstream tree from upstream |
| `validate.sh` | Build artifacts only | No | Yes | Validates assembled downstream tree without mutating dependencies |
| `check-patches.sh` | Only disposable worktree | Yes | Yes | Tests the downstream maintenance framework in isolation against IBM `main` |

### 1. `sync-upstream.sh`

**Owns:**
- Verifying working tree is clean (`git status --porcelain`)
- Upstream remote bootstrap (adds `upstream` if missing, points to `https://github.com/actions/setup-python.git`)
- Upstream remote verification (verifies existing `upstream` points to `actions/setup-python`)
- Fetching latest `upstream/main`
- Resolving exact upstream commit SHA
- Replacing upstream-owned source/config files
- Removing stale renamed upstream config files
- Applying downstream patches in `patches/series` order via `git apply --3way`
- Stopping immediately and identifying the patch if one fails to apply
- Invoking `validate.sh`
- Updating `downstream/UPSTREAM_VERSION` only after validation succeeds
- Showing final working tree status

**Must not:**
- Run `npm audit fix`
- Edit patch contents
- Commit or push
- Silently resolve failed patches
- Silently rewrite an unexpected upstream remote

**Usage:**
```bash
./downstream/scripts/sync-upstream.sh
```

---

### 2. `validate.sh`

**Owns:**
Proving that the assembled tree is valid without changing dependency versions:
- `npm ci`
- `npm test`
- `npm run lint`
- `npm run format-check`
- `npm audit --audit-level=high`
- `npm audit --omit=dev --audit-level=high`
- `npm run build` (regenerates `dist/setup/*` and `dist/cache-save/*`)

**Must not:**
- Fetch upstream
- Apply patches
- Run `npm audit fix`
- Change dependency versions intentionally
- Edit `package.json` or patch files
- Commit or push

**Usage:**
```bash
./downstream/scripts/validate.sh
```

---

### 3. `check-patches.sh`

**Owns:**
Validating the maintenance mechanism itself without mutating the working tree:
- Verifying every entry in `patches/series` exists on disk
- Detecting any `.patch` files not listed in `series`
- Syntax-checking shell scripts (`bash -n`)
- Creating a disposable worktree from IBM `main`
- Running `sync-upstream.sh` within the temporary worktree
- Asserting expected IBM behavior and markers:
  - `IBM/python-versions-pz` default mirror in `action.yml` and `src/install-python.ts`
  - `ppc64le` architecture normalization in `src/setup-python.ts`
  - `package.json` byte-for-byte upstream parity
  - Clean security audits (`0` high-severity vulnerabilities)
- Destroying the disposable worktree cleanly on exit via trap

**Must not:**
- Modify the developer's working tree
- Create permanent production commits
- Push anything
- Modify patch contents

**Usage:**
```bash
./downstream/scripts/check-patches.sh
```

---

## File Ownership Model

### Upstream-Owned
Replaced from the fetched upstream revision:
- `src/`
- `__tests__/`
- `action.yml`
- `package.json`
- `package-lock.json`
- `tsconfig.json`
- Tooling configurations: Jest, ESLint, Prettier

*Acceptance*: Before downstream patches are applied, these paths match the selected upstream revision. Obsolete configuration files removed upstream are deleted downstream.

### Upstream-Owned + Explicitly Patched
Files starting from upstream with deliberate downstream alterations maintained exclusively as patches in `patches/series`:
- `action.yml`
- `src/install-python.ts`
- `src/setup-python.ts`
- Selected `__tests__/` files
- `package-lock.json`

*Current Patches*:
1. `0001-ibm-python-versions-pz.patch`: Configures default Python distribution mirror to IBM/python-versions-pz.
2. `0002-ppc64le-normalization.patch`: Normalizes Node.js `ppc64` architecture detection to `ppc64le`.
3. `0003-ibm-secret-scan-allowlist.patch`: Adds IBM scanner allowlist pragmas for test fixture hashes.
4. `0004-dependency-cve-fixes.patch`: Resolves high-severity CVEs in dependencies (`brace-expansion`, `undici`).

### `package.json`
- **Ownership**: Upstream.
- **Acceptance**: `git diff --exit-code "$UPSTREAM_REF" -- package.json` succeeds after patches are applied. `package.json` remains byte-for-byte identical to upstream.

### `package-lock.json`
- **Ownership**: Upstream base + Security patches.
- **Acceptance**: Starts from upstream lockfile; differences come solely from explicit downstream patches; `npm audit` and `npm audit --omit=dev` pass at high severity; no `npm audit fix`.

### Generated Artifacts
- **Ownership**: Build output (`dist/setup/*`, `dist/cache-save/*`).
- **Acceptance**: Regenerated via `npm run build` during validation; never committed as patches.

### IBM-Owned
- **Ownership**: Downstream repository framework (`downstream/`, governance files).
- **Acceptance**: `sync-upstream.sh` never overwrites these files.

---

## Overall Framework Acceptance Statement

Starting from clean IBM `main`, a single command must fetch the current `actions/setup-python` upstream revision, reconstruct the intended IBM Power/Z downstream tree using only the declared patch series, validate and audit it, rebuild generated artifacts, and record the exact upstream SHA:

```bash
./downstream/scripts/sync-upstream.sh
```

The framework **fails safely** when:
- Upstream remote points somewhere unexpected
- Working tree is dirty
- Upstream ref cannot be fetched or resolved
- A patch no longer applies cleanly
- Any test fails
- Lint or formatting checks fail
- Audit finds a high-or-greater vulnerability
- Build fails
