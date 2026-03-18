# `turbo prune` rewrites `package.json` with sorted keys, invalidating cache

## Bug Summary

When a pnpm monorepo has patched dependencies (`patchedDependencies`), `turbo prune` re-serializes the root `package.json` with alphabetically sorted keys instead of copying it verbatim. This produces a byte-different file with a different hash, which invalidates **all** turbo cache entries when building inside the pruned directory (because `package.json` is a `globalDependency` by default).

Without `patchedDependencies`, `turbo prune` copies `package.json` as-is and the cache works correctly.

## Turbo version

2.8.17

## Package manager

pnpm 10.30.2

## Reproduction

```bash
pnpm install
bash reproduce.sh
```

### Expected output

Step 4 should show `FULL TURBO` — the build in the pruned directory should hit the cache populated in Step 1.

### Actual output

Step 4 shows `0 cached, 2 total` — all cache entries are missed because the pruned `package.json` has a different hash than the original.

Step 5 demonstrates the workaround: copying the original `package.json` into the pruned directory restores the cache (`FULL TURBO`).

## Root Cause

In `crates/turborepo-lib/src/commands/prune.rs`, there are two code paths:

- **Patches exist:** `package.json` is deserialized into a `PackageJson` Rust struct, the patches are pruned, and the struct is re-serialized with `serde_json::to_string_pretty`. Because `PackageJson` uses `BTreeMap` fields (which iterate alphabetically) and `#[serde(flatten)]` for unknown keys, the output has all keys sorted — different from the original file.

- **No patches:** `package.json` is copied verbatim via `copy_file`, preserving the original byte content.

The re-serialized `package.json` is semantically equivalent but byte-different, producing a different hash in the global cache inputs.

## Workaround

After `turbo prune`, copy the original `package.json` over the pruned one:

```bash
turbo prune @repo/web --out-dir pruned
cp package.json pruned/package.json
```
