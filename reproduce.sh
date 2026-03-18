#!/usr/bin/env bash
set -uo pipefail

echo "=== turbo prune cache invalidation bug reproduction ==="
echo ""
echo "turbo $(pnpm turbo --version 2>/dev/null)"
echo ""

# Clean previous state
rm -rf pruned .turbo

# Step 1: Build with --force to populate cache
echo "--- Step 1: Force-building to populate the cache ---"
pnpm turbo build --force --ui=stream 2>&1 | tail -5
echo ""

# Step 2: Prune the monorepo for @repo/web
echo "--- Step 2: Running turbo prune ---"
pnpm turbo prune @repo/web --out-dir pruned 2>&1
echo ""

# Step 3: Show that package.json was rewritten with sorted keys
echo "--- Step 3: Comparing original vs pruned package.json ---"
if diff package.json pruned/package.json > /dev/null 2>&1; then
  echo "package.json is IDENTICAL (no bug)"
else
  echo "BUG: package.json is DIFFERENT (turbo prune rewrote it with sorted keys)"
  echo ""
  echo "  Original hash (git object): $(git hash-object package.json)"
  echo "  Pruned   hash (git object): $(git hash-object pruned/package.json)"
  echo ""
  diff package.json pruned/package.json || true
fi
echo ""

# Step 4: Run build in the pruned directory using the shared cache
echo "--- Step 4: Building in pruned dir with shared cache (expect: FULL TURBO) ---"
pnpm turbo build --cwd=pruned --cache-dir="$(pwd)/.turbo/cache" --ui=stream 2>&1 | grep -E '(Cached|Tasks|Time|TURBO)'
echo ""

# Step 5: Workaround — copy original package.json, rebuild
echo "--- Step 5: Workaround — copy original package.json, rebuild ---"
cp package.json pruned/package.json
pnpm turbo build --cwd=pruned --cache-dir="$(pwd)/.turbo/cache" --ui=stream 2>&1 | grep -E '(Cached|Tasks|Time|TURBO)'
