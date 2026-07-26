# **Distances** Mod for X4: Foundations

Extends travel distances by spreading sector content and updating related map data.
The default version increases distance by 3x from the sector center (moderate).

X4 changes often with EGOSOFT updates. I really liked the [XRSGE mod from Eucharion/Realspace](https://www.nexusmods.com/x4foundations/mods/1140) for its sense of scale, but it also required deeper AI/jobs changes. This mod is inspired by [Expanded Sectors x2](https://www.nexusmods.com/x4foundations/mods/417): it increases sector scale while staying under practical AI limits, and provides tools to regenerate data.

Only sectors covered by generated diffs are modified. Additional sectors from EGOSOFT or other mods are not affected unless you regenerate with their files as input.

A new game is recommended.

## 📚 Documentation

For detailed information, see:
- **User Guide & Feature Details**: This README covers everything you need
- **Technical Documentation**: See [AGENTS.md](AGENTS.md) for developers
- **Comprehensive Guides**: Check `docs/` directory for:
  - `DOCUMENTATION_AUDIT.md` - Complete audit report
  - `DOCUMENTATION_SUMMARY.md` - Executive summary
  - `RELEASE_CHECKLIST.md` - Verification checklist
  - `RESERVED_CODE.md` - Future extensibility

## Using the tools (optional for normal gameplay)

### 1) Prepare `_default` from extracted game files

You need to have vanilla X4 map files in the `_default` folder. Place extracted game files like:
```
_default/
  maps/
    xu_ep2_universe/
      zones.xml
      sectors.xml
      clusters.xml
      sechighways.xml
      zonehighways.xml
      galaxy.xml
  libraries/
    god.xml
  extensions/
    (same structure for DLC files)
```

### 2) Generate mod diffs

```bash
cd distances
bash generate.sh 3
```

For help and usage options:
```bash
bash generate.sh --help
```

The generator reads input files from `./_default/maps/xu_ep2_universe/` by default.

### 3) Enable in X4

1. Start X4
2. Enable the `Distances` extension
3. Prefer a new game for cleanest results

## What gets generated

The script generates diffs for base game and input extensions in:

- `maps/xu_ep2_universe/*.xml` (zones, sectors, sechighways)
- `libraries/god.xml` (fixed station/object positions)
- `extensions/<extension_name>/maps/xu_ep2_universe/*.xml` (DLC content)
- `extensions/<extension_name>/libraries/god.xml` (DLC fixed positions)

It includes DLC naming special-cases internally (Split=`dlc4`, Timelines=`dlc7`), also supports community mods that use plain `sectors.xml` / `zones.xml`, and skips the `Distances` extension itself when scanning input extensions.

Commented-out XML blocks in `sectors.xml`, `zones.xml` and related map inputs are ignored during generation.

## Hazard Exclusions

Some hazardous sectors are excluded on purpose to avoid unsafe station placement (for example Tide/radiation sectors).

Story, tutorial and scenario-only content found in `god.xml` is also excluded automatically because it is not part of the open world.

You can adjust this in `lib/config.sh` via `EXCLUDE_SECTORS`.

## Travel Network Safeguards

### Default mode (no `--no-highways`)

By default, the generator enlarges sectors while preserving travel-critical layout behavior:

- regular sector content is spread/scaled (with angular distribution + clamp/jitter safeguards)
- travel-network anchors (gates/highway-critical links) stay protected to keep stable routing

### `--no-highways` mode

If needed, you can switch to `--no-highways` (example: `bash generate.sh 3 --no-highways`).

In this mode:

- **sector-level highways are removed** (sector connections referencing `zonehighways`)
- **gates/SHCon references are kept** (no SHCon macro deletion)
- **SuperHighways are preserved**
- **Accelerators are preserved** (not explicitly removed by this mode)
- gate/SHCon-related sector offsets can be moved by scaling to follow the stretched layout
- gate/SHCon travel anchors are moved in **scale-only** mode (no angular rotation / jitter / clamp) so they stay numerically aligned with superhighway entry/exit scaling

Note: `zonehighways.xml` is used as input reference data from `_default`, but no output diff file is generated for it.

### Defense Station Positioning

**Defense stations** (identified by "defence" or "defense" in their ID) deserve special handling:

- **Without --no-highways** (default): Defense stations remain exactly where they are. They are excluded from scaling to maintain their defensive position near the gates they protect.

- **With --no-highways**: Defense stations are scaled by the same factor and reparented to their enclosing sector, so their placement remains coherent with moved gate/sector layout.

For fixed GOD placements (`god.xml` entries with explicit `<position ... />`), non-defense stations stuck in a protected gate/highway zone are reparented directly to the enclosing sector, so they do not stay artificially close to the original travel network layout.

Procedural GOD placements that only define location rules without explicit coordinates remain driven by the game and may stay closer to protected travel zones.

## Update Workflow (after patch/new extraction)

1. Update `_default/maps/xu_ep2_universe/` with new extracted game files
2. (Optionally update DLC extensions in `_default/extensions/`)
3. Re-run `generate.sh` with your desired factor

## Script Architecture

`generate.sh` is a thin orchestrator: it only handles CLI/interactive input,
cleanup of previously generated files, and looping over the base game plus
every input extension. All actual logic is split into small, focused files
so each concern can be read, tested and maintained independently:

```
generate.sh                          Orchestrator: options, cleanup, DLC loop, summary
lib/config.sh                         Tuning constants (excluded sectors, clamp/jitter values)
lib/dlc.sh                            DLC folder name -> map file prefix resolution
lib/process.sh                        Thin bash wrappers calling the AWK generators
lib/awk/common.awk                    Shared helpers: XML comment stripping, clamp,
                                      per-sector radius ceiling, deterministic hash/jitter,
                                      angular rotation
lib/awk/emit_sectors.awk              sectors.xml: position scaling
lib/awk/emit_zones.awk                zones.xml: internal zone connection scaling
lib/awk/emit_sechighways.awk          sechighways.xml: superhighway entry/exit scaling
lib/awk/emit_god.awk                  god.xml: fixed station/object position scaling,
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
- **Angular distribution**: positions are rotated pseudo-randomly around the sector center
  based on their connection ID. This spreads zones and stations around the sector
  rather than having them all radiate outward in their original directions, creating
  more natural spatial distribution.
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
  they are left completely untouched (unless --no-highways is used).

### Performance & Resource Notes

- **Generation time:** ~2-5 seconds (3x factor on modern hardware)
- **CPU usage:** Single-threaded AWK (~1 core, low overhead)
- **Memory:** Minimal (<100 MB)
- **Input files:** ~1-2 MB total (XML size)
- **Output files:** ~5-10 MB total (diff patches)
- **Reproducibility:** Same inputs → same outputs (deterministic)
- **Backward compatible:** Existing saves continue to work

## Notes

- This mod only generates map/GOD diffs
- No AI/jobs overhaul
- Some procedural station placements may remain closer to highways or gates by design, to preserve stable travel topology
- No performance impact in-game (changes are manifest before startup)


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



