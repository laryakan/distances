# AGENTS.md - Distances Mod Documentation

This document provides essential information for agents working on the Distances Mod project.

## Project Overview

### What is the Distances Mod?

The Distances Mod is a scaling enhancement for X4: Foundations that multiplies distances between sectors and zones.

**Key Goal**: Make the X4 universe feel larger by increasing travel times and strategic positioning.

### Project Structure

- _default/maps/xu_ep2_universe/: Vanilla source XML (zones, sectors, sechighways, clusters)
- _default/libraries/god.xml: Vanilla source GOD fixed positions
- _default/extensions/ego_dlc_*/: DLC source XML (7 DLCs)
- maps/xu_ep2_universe/: OUTPUT - Generated vanilla map diffs
- libraries/god.xml: OUTPUT - Generated vanilla GOD diff
- extensions/ego_dlc_*/: OUTPUT - Generated DLC diffs
- lib/generate.sh: Main script
- lib/config.sh: Configuration constants
- lib/dlc.sh: DLC filename resolution
- lib/process.sh: Processing wrappers
- lib/awk/: Generator scripts

## Quick Start

### Run generate.sh

    ./generate.sh <factor> [--no-highways]
    ./generate.sh --help        # Show help

### Parameters

- <factor>: Scaling multiplier (integer: 2, 3, 5, 10)
- --no-highways: Remove sector-level Highway links (`ref="zonehighways"`), while keeping SHCon/SuperHighway structures
- --help, -h: Show usage information

### Examples

    ./generate.sh 2
    ./generate.sh 5 --no-highways
    ./generate.sh --help

## Critical Architecture

### Angular Distribution (Zone Spreading)

When zones/stations are scaled outward, they are also rotated pseudo-randomly around the sector center.

**Problem solved:** Without rotation, all objects in a sector would radiate outward in their original directions, creating a "spoked wheel" appearance.

**Solution:** Each zone/station gets a deterministic angular rotation based on its connection ID. This spreads them around the sector more naturally.

**How it works:**
- Position is scaled by factor: `(x, z) → (x*factor, z*factor)`
- Then rotated by seed-based angle in range `[-π, +π]`
- Same seed always produces same rotation (reproducible)
- Radius stays the same, angle changes

This creates a more dispersed, natural distribution without sacrificing reproducibility.

### Highway vs SuperHighway

**Highway** (sector-level):
- Direct sector connections
- Removable with --no-highways
- Defined in zonehighways.xml

**SuperHighway** (cluster-level):
- Macro structures connecting clusters
- Macros must NEVER be removed
- SHCon gates must stay present (zones + sectors + clusters stay in sync)
- Accelerators are not removed by `--no-highways`

### SHCon (SuperHighway Connection)

Special gate zones with three synchronized components:
1. Zone definition in zones.xml
2. Zone reference in sectors.xml
3. SuperHighway connection in clusters.xml

**Default mode (no --no-highways):** These three parts remain completely untouched.

**With --no-highways:** 
- All three parts remain in sync (zone macro is NOT deleted)
- Gate/SHCon offsets in sector connections ARE SCALED proportionally
- Superhighway entry/exit positions ARE SCALED with the same factor
- Both use scale-only transforms (no angular rotation / jitter / clamp) to maintain 
  numerical alignment between superhighway anchors and their corresponding SHCon gate zones
  
This ensures that as sectors expand, travel gates and superhighway entry/exit points move 
together proportionally outward, avoiding "missing zone" errors that occur if they move 
at different rates or in different directions.

### Defense Stations Behavior

**Defense stations** (with "defence"/"defense" in ID) that guard gates receive special treatment:

- **Default (no --no-highways)**: Remain untouched at their original position to maintain gate defense integrity.
- **With --no-highways**: Are scaled by the same factor as their enclosing sector and reparented to it to stay coherent with moved gate/sector layout.

This keeps defense placements coherent in stretched sectors without breaking gate/SuperHighway references.

## Troubleshooting

### Getting Help

    ./generate.sh --help        # Show detailed usage info
    ./generate.sh -h            # Short help

The help output explains:
- Factor scaling multiplier (must be integer)
- --no-highways option (removes sector links to `zonehighways` only)
- File input/output locations

### "Highway superhighway005 could not find a map zone"

This error occurs when superhighway entry/exit points don't align with SHCon gate zones.

**With the current implementation:**
- In default mode: SHCon stays untouched, superhighways stay untouched → alignment preserved
- In `--no-highways` mode: Both SHCon gates and superhighway anchors are scaled by the same factor 
  using scale-only transforms → alignment maintained

If this error still occurs:
- Check that all three SHCon components are in sync:
  - zones.xml has the zone defined
  - sectors.xml has the ref
  - clusters.xml has the connection
- Ensure SHCon was not removed by another patch
- Verify both gate AND superhighway were scaled (not just one)

### Defense Stations Far from Their Gates (--no-highways)

If you notice defense stations appearing far from gates when using --no-highways:
- This is **expected and correct** behavior
- Defense stations are scaled by the factor along with their sector
- Gates/SHCon remain present; stations may still be farther in absolute distance due to scaling
- Verify with: `grep "defence\|defense" libraries/god.xml` (should have position modifications)

### generate.sh fails on new DLC

Check:
1. Directory: extensions/ego_dlc_<name>/maps/xu_ep2_universe/
2. File naming: <prefix>_zones.xml, <prefix>_sectors.xml
3. Update get_dlc_map_prefix() in lib/dlc.sh if needed

### Generated XML has CRLF line endings

Run: sed -i 's/\r$//' maps/xu_ep2_universe/*.xml

### SHCon zones aren't connected in game

SHCon zone macros must still exist in source/generated data. Do not delete them via
`<remove>` patches when using `--no-highways`.

## Common Tasks

### Add a new DLC

    mkdir -p extensions/ego_dlc_newname/maps/xu_ep2_universe
    cp dlc_files/* extensions/ego_dlc_newname/maps/xu_ep2_universe/
    (Update lib/dlc.sh if naming doesn't match)
    ./generate.sh 2

### Debug an AWK script

    bash -x ./generate.sh 2 2>&1 | grep "emit_zones"

### Verify SHCon handling

1. Check zones: grep "SHCon" _default/maps/xu_ep2_universe/zones.xml
2. Check sectors: grep "SHCon" _default/maps/xu_ep2_universe/sectors.xml
3. Check clusters: grep "SHCon" _default/maps/xu_ep2_universe/clusters.xml
4. If --no-highways, verify SHCon entries are still present in generated output files

## File Reference

- generate.sh: Main orchestration (with --help), calls process functions for all file types
- config.sh: Constants (exclude patterns, radii, jitter)
- dlc.sh: DLC prefix mapping
- process.sh: AWK wrappers (zones, sectors, sechighways, god)
- emit_sectors.awk: Scaled sector positions
- emit_zones.awk: Scaled resource zones
- emit_sechighways.awk: Scaled superhighway entry/exit
- emit_god.awk: Fixed station/object position scaling + protected-zone reparenting

## Key Variables

- FACTOR: Scaling multiplier
- NO_HIGHWAYS: 0 or 1 flag
- exclude_pattern: Regex of protected zones
- file_counts: Vanilla files processed
- dlc_counts: DLC files processed

---

Last Updated: 2026-07-25

For agents: Use this as the source of truth for project architecture and common tasks.
