#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

npm ci
npm test
npm run lint
npm run format-check
npm audit --audit-level=high
npm audit --omit=dev --audit-level=high
npm run build
