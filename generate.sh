#!/bin/bash
#
# Distances Mod - Generate Script
# Transforms vanilla sectors.xml by multiplying zone distances
#
# Usage:
#   ./generate.sh [factor]
#   INPUT_DIR=/path/to/input ./generate.sh [factor]
#
# Examples:
#   ./generate.sh           # Interactive prompt
#   ./generate.sh 2.0       # 2x distance
#   ./generate.sh 3.5       # 3.5x distance
#
# Organisation :
#   lib/config.sh   - constantes de reglage (secteurs exclus, clamps, jitter)
#   lib/dlc.sh       - resolution des noms de fichiers par DLC
#   lib/process.sh   - enveloppes bash autour des generateurs AWK
#   awk/common.awk   - fonctions partagees (parsing, clamp, jitter, hash)
#   awk/emit_*.awk   - toute la logique de calcul de position, par fichier
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/dlc.sh"
source "${SCRIPT_DIR}/lib/process.sh"
DEFAULT_INPUT_DIR="${SCRIPT_DIR}/_default"
INPUT_DIR="${INPUT_DIR:-$DEFAULT_INPUT_DIR}"
if [[ ! -d "$INPUT_DIR" ]]; then
    echo "Error: Invalid INPUT_DIR '$INPUT_DIR'" >&2
    exit 1
fi
INPUT_DIR="$(cd "$INPUT_DIR" && pwd)"
VANILLA_SECTORS="${INPUT_DIR}/maps/xu_ep2_universe/sectors.xml"
VANILLA_ZONES="${INPUT_DIR}/maps/xu_ep2_universe/zones.xml"
VANILLA_GOD="${INPUT_DIR}/libraries/god.xml"
OUTPUT_SECTORS="${SCRIPT_DIR}/maps/xu_ep2_universe/sectors.xml"
OUTPUT_ZONES="${SCRIPT_DIR}/maps/xu_ep2_universe/zones.xml"
OUTPUT_GOD="${SCRIPT_DIR}/libraries/god.xml"
# Get factor from argument or prompt
if [[ $# -eq 0 ]]; then
    echo "=== Distances Mod Generator ==="
    echo ""
    echo "Multiplication factor for zone distances:"
    echo "  2.0 = 2x distance (moderate)"
    echo "  2.5 = 2.5x distance (balanced)"
    echo "  3.0 = 3x distance (recommended)"
    echo "  4.0 = 4x distance (large)"
    echo ""
    read -p "Enter factor [3.0]: " FACTOR
    FACTOR="${FACTOR:-3.0}"
else
    FACTOR="$1"
fi
# Validate
if ! [[ "$FACTOR" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: Invalid factor '$FACTOR'" >&2
    exit 1
fi
if [[ ! -f "$VANILLA_SECTORS" ]]; then
    echo "Error: Input sectors file not found: $VANILLA_SECTORS" >&2
    echo "Provide INPUT_DIR or generate ${DEFAULT_INPUT_DIR} with: cd /path/to/X4 && bash extensions/Distances/extract_default.sh" >&2
    exit 1
fi
if [[ ! -f "$VANILLA_ZONES" ]]; then
    echo "Warning: input zones.xml not found: $VANILLA_ZONES" >&2
fi
echo "Generating with factor $FACTOR..."
echo "Using input directory: $INPUT_DIR"
echo "Excluding hazard sectors..."
echo ""
# Purge previously generated files
echo "Cleaning up old generated files..."
rm -f "${SCRIPT_DIR}/maps/xu_ep2_universe"/*.xml 2>/dev/null || true
rm -f "${SCRIPT_DIR}/libraries/god.xml" 2>/dev/null || true
find "${SCRIPT_DIR}/extensions" -mindepth 2 -path "*/maps/xu_ep2_universe/*.xml" -type f -delete 2>/dev/null || true
find "${SCRIPT_DIR}/extensions" -mindepth 2 -path "*/libraries/god.xml" -type f -delete 2>/dev/null || true
echo ""
exclude_pattern="$(build_exclude_pattern)"
total_sectors_modified=0
total_zones_modified=0
total_resource_zones_added=0
total_god_positions_modified=0
# Process base game sectors
if [[ -f "$VANILLA_SECTORS" ]]; then
    mkdir -p "$(dirname "$OUTPUT_SECTORS")"
    process_sectors_file "$VANILLA_SECTORS" "$OUTPUT_SECTORS" "$VANILLA_ZONES"
    modified=$(awk '/<position x=/{c++} END{print c+0}' "$OUTPUT_SECTORS")
    added=$(awk '/_resourceextra/{c++} END{print c+0}' "$OUTPUT_SECTORS")
    total_sectors_modified=$((total_sectors_modified + modified))
    total_resource_zones_added=$((total_resource_zones_added + added))
    echo "OK Base game sectors: $modified positions"
    echo "OK Base game extra resource zones: $added"
fi
# Process base game zones
if [[ -f "$VANILLA_ZONES" ]]; then
    mkdir -p "$(dirname "$OUTPUT_ZONES")"
    process_zones_file "$VANILLA_ZONES" "$OUTPUT_ZONES"
    modified=$(awk '/<replace sel=/{c++} END{print c+0}' "$OUTPUT_ZONES")
    total_zones_modified=$((total_zones_modified + modified))
    echo "OK Base game zones: $modified zones repositioned"
    if (( modified == 0 )); then
        echo "WARN Base game zones: no matching zone entries found for current parser"
    fi
else
    echo "WARN Base game zones.xml not found, skipping..."
fi
# Process base game GOD
if [[ -f "$VANILLA_GOD" ]]; then
    mkdir -p "$(dirname "$OUTPUT_GOD")"
    process_god_file "$VANILLA_GOD" "$OUTPUT_GOD" "$VANILLA_SECTORS" "$VANILLA_ZONES"
    modified=$(awk '/<replace sel=/{c++} END{print c+0}' "$OUTPUT_GOD")
    total_god_positions_modified=$((total_god_positions_modified + modified))
    echo "OK Base game GOD: $modified fixed positions"
else
    echo "WARN Base game god.xml not found, skipping..."
fi
echo ""
echo "Processing input extensions..."
echo ""
# Process extension sectors and zones from input directory.
if [[ -d "${INPUT_DIR}/extensions" ]]; then
    for dlc_dir in "${INPUT_DIR}"/extensions/*; do
        if [[ -d "$dlc_dir" ]]; then
            dlc_name=$(basename "$dlc_dir")
            dlc_name_lc=$(printf '%s' "$dlc_name" | tr '[:upper:]' '[:lower:]')
            if [[ "$dlc_name_lc" == "distances" ]]; then
                continue
            fi
            dlc_prefix=$(get_dlc_map_prefix "$dlc_name")
            map_dir="${dlc_dir}/maps/xu_ep2_universe"
            sectors_basename="${dlc_prefix}_sectors.xml"
            zones_basename="${dlc_prefix}_zones.xml"
            if [[ -f "${map_dir}/${sectors_basename}" ]]; then
                :
            elif [[ -f "${map_dir}/sectors.xml" ]]; then
                sectors_basename="sectors.xml"
                zones_basename="zones.xml"
            else
                detected_file=$(find "$map_dir" -maxdepth 1 -type f \( -name "*_sectors.xml" -o -name "sectors.xml" \) 2>/dev/null | head -n 1)
                if [[ -n "$detected_file" ]]; then
                    sectors_basename=$(basename "$detected_file")
                    zones_basename="${sectors_basename%sectors.xml}zones.xml"
                fi
            fi
            dlc_sectors="${map_dir}/${sectors_basename}"
            dlc_zones="${map_dir}/${zones_basename}"
            dlc_god="${dlc_dir}/libraries/god.xml"
            if [[ -f "$dlc_sectors" ]]; then
                dlc_sectors_output="${SCRIPT_DIR}/extensions/${dlc_name}/maps/xu_ep2_universe/${sectors_basename}"
                dlc_zones_output="${SCRIPT_DIR}/extensions/${dlc_name}/maps/xu_ep2_universe/${zones_basename}"
                dlc_god_output="${SCRIPT_DIR}/extensions/${dlc_name}/libraries/god.xml"
                mkdir -p "$(dirname "$dlc_sectors_output")"
                # Process sectors
                process_sectors_file "$dlc_sectors" "$dlc_sectors_output" "$dlc_zones"
                sectors_modified=$(awk '/<position x=/{c++} END{print c+0}' "$dlc_sectors_output")
                added=$(awk '/_resourceextra/{c++} END{print c+0}' "$dlc_sectors_output")
                total_sectors_modified=$((total_sectors_modified + sectors_modified))
                total_resource_zones_added=$((total_resource_zones_added + added))
                # Process zones if available
                zones_modified=0
                if [[ -f "$dlc_zones" ]]; then
                    mkdir -p "$(dirname "$dlc_zones_output")"
                    process_zones_file "$dlc_zones" "$dlc_zones_output"
                    zones_modified=$(awk '/<replace sel=/{c++} END{print c+0}' "$dlc_zones_output")
                    total_zones_modified=$((total_zones_modified + zones_modified))
                fi
                # Process GOD if available
                god_modified=0
                if [[ -f "$dlc_god" ]]; then
                    mkdir -p "$(dirname "$dlc_god_output")"
                    process_god_file "$dlc_god" "$dlc_god_output" "$dlc_sectors" "$dlc_zones"
                    god_modified=$(awk '/<replace sel=/{c++} END{print c+0}' "$dlc_god_output")
                    total_god_positions_modified=$((total_god_positions_modified + god_modified))
                fi
                if (( sectors_modified > 0 || zones_modified > 0 || god_modified > 0 )); then
                    echo "OK $dlc_name: $sectors_modified sectors, $zones_modified zones, $god_modified GOD fixed positions, $added extra resource zones"
                fi
            else
                echo "WARN $dlc_name: sectors file not found"
            fi
        fi
    done
else
    echo "WARN No input extensions directory found"
fi
# Summary
excluded_count=${#EXCLUDE_SECTORS[@]}
echo ""
echo "========================================="
echo "OK Generation completed!"
echo "  Sector positions: $total_sectors_modified"
echo "  Resource zones: $total_zones_modified"
echo "  GOD fixed positions: $total_god_positions_modified"
echo "  Extra resource zones added: $total_resource_zones_added"
echo "  Sectors excluded: $excluded_count"
echo "  Factor: ${FACTOR}x"
echo "========================================="
