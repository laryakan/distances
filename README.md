# **Distances** Mod for X4: Foundations

Extends travel distances by spreading sector content and updating related map data.
Default version increase distance by 3 from the sector center (not too much).

X4 is subject to many changes from EGOSOFT. I was fond of the [XRSGE mod from Eucharion/Realspace](https://www.nexusmods.com/x4foundations/mods/1140), the sentiment of space scale was real (I really recommend it). But to achieve what he have done, many things had to be modified, like the AI jobs. This mod, inspired by the old (Expanded Sectors x2)[https://www.nexusmods.com/x4foundations/mods/417] is increasing sector side below the AI logic limit, and offer tools to do more.

Sector are modified, and such, do not impact additional sectors added by EGOSOFT or other mods, unless you use the tool to regenerate files.

In order to function, it requires a new game.

## Using the tools (not needed to use the mod the regular way)

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

For fixed GOD placements (`god.xml` entries with explicit `<position ... />`), the generator still reassigns stations stuck in a protected gate/highway zone to the nearest regular zone in the same sector, so they do not stay artificially close to the original travel network layout.

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
  position inside a small gate/highway (SHCon) zone are reassigned to the
  nearest non-protected zone in the same sector, so they benefit from the
  mod's spread instead of staying pinned near the original travel network.

## Notes

- This mod only generates map/GOD diffs
- No AI/jobs overhaul
- Some procedural station placements may remain closer to highways or gates by design, to preserve stable travel topology

# Requirements ?
- NONE

# Redistribution and modification

## BSD 2-Clause License

### Copyright (c) 2026, laryakan

You are free to use, modify and redistribute any code or assets of mine which is not directly extracted from the game as soon as you mention the above Copyright.
A link to my github is provided below. A little mention is all I ask.

- github : https://github.com/laryakan/distances
- nexus : https://www.nexusmods.com/x4foundations/mods/2232
- nexus user : https://next.nexusmods.com/profile/Laryakan