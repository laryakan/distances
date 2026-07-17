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

You can adjust this in `generate.sh` via `EXCLUDE_SECTORS`.

## Travel Network Safeguards

To keep gates, highways and travel links functional, the generator intentionally preserves some travel-critical zones:

- gate zones
- highway entry/exit zones
- related protected travel zones

Those zones are not moved in the same way as regular open-world zones.

For fixed GOD placements (`god.xml` entries with explicit `<position ... />`), the generator still compensates for protected highway/gate zones so stations do not stay artificially close to the original travel network layout.

Procedural GOD placements that only define location rules without explicit coordinates remain driven by the game and may stay closer to protected travel zones.

## Update Workflow (after patch/new extraction)

1. Re-run `extract_default.sh` from extracted root
2. Refresh `extensions/Distances/_default` or point `INPUT_DIR` to the updated source directory
3. Re-run `generate.sh`

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