# **Distances** Mod for X4: Foundations

Extends travel distances by spreading sector content and updating related map data.
The default version increases distance by 3x from the sector center (moderate).

X4 changes often with EGOSOFT updates. I really liked the [XRSGE mod from Eucharion/Realspace](https://www.nexusmods.com/x4foundations/mods/1140) for its sense of scale, but it also required deeper AI/jobs changes. This mod is inspired by [Expanded Sectors x2](https://www.nexusmods.com/x4foundations/mods/417): it increases sector scale while staying under practical AI limits, and provides tools to regenerate data.

Only sectors covered by generated diffs are modified. Additional sectors from EGOSOFT or other mods are not affected unless you regenerate with their files as input.

A new game is recommended.

## Using the tools (optional for normal gameplay)

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

By default, the generator reads input files from `./_default`.

You can also override the source data directory with `INPUT_DIR`, for example to process extracted files or sibling extensions without copying them into `_default` first:

```bash
INPUT_DIR=/path/to/x4-or-mod-root bash generate.sh 3.0
```

### 3) Enable in X4

1. Start X4
2. Enable the `Distances` extension
3. Prefer a new game for cleanest results

## What gets generated

The script generates diffs for base game and input extensions in:

- `maps/xu_ep2_universe/*.xml`
- `libraries/god.xml`
- `extensions/<extension_name>/...`

It includes DLC naming special-cases internally (Split=`dlc4`, Timelines=`dlc7`), also supports community mods that use plain `sectors.xml` / `zones.xml`, and skips the `Distances` extension itself when scanning input extensions.

Commented-out XML blocks in `sectors.xml`, `zones.xml` and related map inputs are ignored during generation.

## Hazard Exclusions

Some hazardous sectors are excluded on purpose to avoid unsafe station placement (for example Tide/radiation sectors).

Story, tutorial and scenario-only content found in `god.xml` is also excluded automatically because it is not part of the open world.

You can adjust this in `lib/config.sh` via `EXCLUDE_SECTORS`.

## Travel Network Safeguards

To keep gates, highways and travel links functional, the generator intentionally preserves some travel-critical zones:

- gate zones
- highway entry/exit zones
- related protected travel zones

Those zones are not moved in the same way as regular open-world zones.

If needed, you can switch to `--no-highways` (example: `bash generate.sh --no-highways 3.0`). This single toggle disables travel-network protection and removes **sector highway connections** in non-protected sectors. **SuperHighways are preserved**.

For fixed GOD placements (`god.xml` entries with explicit `<position ... />`), the generator still reparents stations stuck in a protected gate/highway zone directly to the enclosing sector, so they do not stay artificially close to the original travel network layout.

Procedural GOD placements that only define location rules without explicit coordinates remain driven by the game and may stay closer to protected travel zones.

## Update Workflow (after patch/new extraction)

1. Re-run `extract_default.sh` from extracted root
2. Refresh `extensions/Distances/_default` or point `INPUT_DIR` to the updated source directory
3. Re-run `generate.sh`

## Script Architecture

`generate.sh` is a thin orchestrator: it only handles CLI/interactive input,
cleanup of previously generated files, and looping over the base game plus
every input extension. All actual logic is split into small, focused files
so each concern can be read, tested and maintained independently:

```
generate.sh              Orchestrator: options, cleanup, DLC loop, summary
lib/config.sh             Tuning constants (excluded sectors, clamp/jitter values)
lib/dlc.sh                 DLC folder name -> map file prefix resolution
lib/process.sh             Thin bash wrappers calling the AWK generators
lib/awk/common.awk         Shared helpers: XML comment stripping, clamp,
                           per-sector radius ceiling, deterministic hash/jitter
lib/awk/emit_sectors.awk   sectors.xml: position scaling + extra resource zones
lib/awk/emit_zones.awk     zones.xml: internal zone connection scaling
lib/awk/emit_god.awk       god.xml: fixed station/object position scaling,
                           including protected-zone reparenting
```

All position math (scaling, clamping, axis-jitter, protected-zone
reparenting) is implemented directly in AWK for performance and clarity;
the bash layer only assembles file paths/parameters and writes the
resulting `<diff>` XML.

Two safeguards worth knowing about when tuning the generator:

- **Dynamic per-sector clamp**: some vanilla/DLC sectors already exceed the
  base clamp radius (e.g. Hatikvah's Choice I). The effective ceiling used
  for a sector never goes below its own vanilla extent (`NATURAL_RADIUS_HEADROOM`
  in `lib/config.sh`), so it no longer flattens those sectors onto a single circle.
- **Zero-axis jitter**: when a scaled X or Z coordinate lands exactly on 0
  (common in vanilla data), a small deterministic pseudo-random offset
  (`JITTER_FRACTION` / `JITTER_MIN_ABS`) is applied so objects don't pile up
  along the sector's axes. It is reproducible: the same input always
  produces the same output.
- **Protected-zone reparenting**: stations/objects with a fixed `god.xml`
  position inside a small gate/highway (SHCon) zone are reassigned directly
  to the enclosing sector (`location class="sector"`) instead of a sibling
  zone, so they benefit from the mod's spread without risking a "nearest
  zone" guess landing them inside a highway-only zone. Defense stations
  guarding a gate (id containing `defence`/`defense`) are the one exception:
  they are left completely untouched.

## Notes

- This mod only generates map/GOD diffs
- No AI/jobs overhaul
- Some procedural station placements may remain closer to highways or gates by design, to preserve stable travel topology

## Requirements
- NONE

## Redistribution and modification

## BSD 2-Clause License

### Copyright (c) 2026, laryakan

You are free to use, modify, and redistribute any code or assets of mine that are not directly extracted from the game, as long as you keep the copyright notice above.
A link to my GitHub is provided below. A small mention is all I ask.

--- THIS MOD ---
- github : https://github.com/laryakan/distances
- nexus : https://www.nexusmods.com/x4foundations/mods/2232
- steam : https://steamcommunity.com/sharedfiles/filedetails/?id=3764127388

--- OTHER MODS ---
- nexus user mods : https://www.nexusmods.com/games/x4foundations/mods?author=laryakan
- steam user mods : https://steamcommunity.com/id/laryakan/myworkshopfiles/?appid=392160
