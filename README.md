# Distances Mod for X4: Foundations

Extends travel distances by spreading sector content and updating related map data.

## Quick Setup

### 1) Prepare `_default` from extracted game files

`extract_default.sh` is designed to run from the root of your extracted X4 files.

Example:
```bash
# from your extracted X4 root
./extract_default.sh
```

This creates a `_default` folder next to the script.

Then copy it into the mod folder:
```bash
rm -rf .../distances/_default
mv _default .../distances/_default
```

### 2) Generate mod diffs

```bash
cd distances
bash generate.sh 3.0
```

You can also run without argument to choose interactively.

### 3) Enable in X4

1. Start X4
2. Enable the `Distances` extension
3. Prefer a new game for cleanest results

## What gets generated

The script generates diffs for base game and installed DLC in:

- `maps/xu_ep2_universe/*.xml`
- `libraries/god.xml`
- `extensions/ego_dlc_*/...`

It includes DLC naming special-cases internally (Split=`dlc4`, Timelines=`dlc7`).

## Hazard Exclusions

Some hazardous sectors are excluded on purpose to avoid unsafe station placement (for example Tide/radiation sectors).

You can adjust this in `generate.sh` via `EXCLUDE_SECTORS`.

## Update Workflow (after patch/new extraction)

1. Re-run `extract_default.sh` from extracted root
2. Replace `extensions/Distances/_default`
3. Re-run `generate.sh`

## Notes

- This mod only generates map/GOD diffs
- No AI/jobs overhaul
