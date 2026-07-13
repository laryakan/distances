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
