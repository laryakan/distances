#!/bin/bash
# Distances Mod - Main generation script
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FACTOR="${1:-}"
NO_HIGHWAYS=0

# Display help
show_help() {
    cat << 'EOF'
Distances Mod - Generation Script

Usage: ./generate.sh <factor> [options]

Arguments:
  <factor>          Scaling multiplier (positive integer)
                    Examples: 2, 3, 5, 10

Options:
  --no-highways, --no-highway
                    Remove sector-level Highway connections
                    - Keeps SHCon gate zones and SuperHighways intact
                    - Keeps Accelerators intact
                    - Removes only sector links that reference zonehighways
                    (avoids dangling macro references in index/macros)

  --help, -h        Show this help message

Examples:
  ./generate.sh 2           # Scale by 2x, keep highways
  ./generate.sh 3 --no-highways  # Scale by 3x, remove highways
  ./generate.sh 5 --no-highways    # Scale by 5x, remove highways

Notes:
  - Output files go to: maps/xu_ep2_universe/
  - DLC files are read from: _default/extensions/ego_dlc_*/
  - Input files must be in: _default/maps/xu_ep2_universe/

EOF
}

# Check for help option
if [[ "$FACTOR" == "--help" ]] || [[ "$FACTOR" == "-h" ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
    exit 0
fi

if [[ -z "$FACTOR" ]]; then
    echo "Error: Missing factor argument"
    echo "Usage: $0 <factor> [--no-highways|--no-highway]"
    echo "Run '$0 --help' for more information"
    exit 1
fi

if ! [[ "$FACTOR" =~ ^[0-9]+$ ]] || (( FACTOR < 1 )); then
    echo "Error: factor must be a positive integer (got: $FACTOR)"
    exit 1
fi

if [[ "$2" == "--no-highways" ]] || [[ "$2" == "--no-highway" ]]; then
    NO_HIGHWAYS=1
fi

export FACTOR NO_HIGHWAYS SCRIPT_DIR

source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/dlc.sh"
source "${SCRIPT_DIR}/lib/process.sh"

exclude_pattern=$(build_exclude_pattern)
export exclude_pattern

# Cleanup previously generated files
echo "Cleaning up previous generation..."
rm -rf "${SCRIPT_DIR}/maps" "${SCRIPT_DIR}/extensions" "${SCRIPT_DIR}/libraries"

mkdir -p "${SCRIPT_DIR}/maps/xu_ep2_universe"

echo "=========================================="
echo "Distances Mod - Generation Script"
echo "=========================================="
echo "Factor: ${FACTOR}x"
echo "Remove Highways: $([ $NO_HIGHWAYS -eq 1 ] && echo "YES" || echo "NO")"
echo ""

echo "Processing Vanilla (Base Game)..."
VANILLA_SRC="${SCRIPT_DIR}/_default/maps/xu_ep2_universe"
VANILLA_OUT="${SCRIPT_DIR}/maps/xu_ep2_universe"

if [[ -f "${VANILLA_SRC}/zones.xml" ]]; then
    echo "  - zones.xml"
    process_zones_file "${VANILLA_SRC}/zones.xml" "${VANILLA_OUT}/zones.xml"
fi

if [[ -f "${VANILLA_SRC}/sectors.xml" ]]; then
    echo "  - sectors.xml"
    zones_ref=""
    [[ -f "${VANILLA_SRC}/zones.xml" ]] && zones_ref="${VANILLA_SRC}/zones.xml"
    process_sectors_file "${VANILLA_SRC}/sectors.xml" "${VANILLA_OUT}/sectors.xml" "$zones_ref"
fi

if [[ -f "${VANILLA_SRC}/sechighways.xml" ]]; then
    echo "  - sechighways.xml"
    process_sechighways_file "${VANILLA_SRC}/sechighways.xml" "${VANILLA_OUT}/sechighways.xml"
fi

# Process god.xml for vanilla
if [[ -f "${SCRIPT_DIR}/_default/libraries/god.xml" ]]; then
    echo "  - god.xml"
    sectors_ref=""
    zones_ref=""
    [[ -f "${VANILLA_SRC}/sectors.xml" ]] && sectors_ref="${VANILLA_SRC}/sectors.xml"
    [[ -f "${VANILLA_SRC}/zones.xml" ]] && zones_ref="${VANILLA_SRC}/zones.xml"
    mkdir -p "${SCRIPT_DIR}/libraries"
    process_god_file "${SCRIPT_DIR}/_default/libraries/god.xml" "${SCRIPT_DIR}/libraries/god.xml" "$sectors_ref" "$zones_ref"
fi

echo ""

DLC_SRC_DIR="${SCRIPT_DIR}/_default/extensions"
DLC_OUT_DIR="${SCRIPT_DIR}/extensions"
DLC_NAMES=("ego_dlc_boron" "ego_dlc_mini_01" "ego_dlc_mini_02" "ego_dlc_pirate" "ego_dlc_split" "ego_dlc_terran" "ego_dlc_timelines")

for dlc_name in "${DLC_NAMES[@]}"; do
    DLC_SRC="${DLC_SRC_DIR}/${dlc_name}/maps/xu_ep2_universe"
    if [[ ! -d "$DLC_SRC" ]]; then
        continue
    fi
    
    DLC_OUT="${DLC_OUT_DIR}/${dlc_name}/maps/xu_ep2_universe"
    mkdir -p "$DLC_OUT"
    
    dlc_prefix=$(get_dlc_map_prefix "$dlc_name")
    dlc_file_count=0
    
    echo "Processing DLC: $dlc_name"
    
    dlc_zones_file="${DLC_SRC}/${dlc_prefix}_zones.xml"
    if [[ -f "$dlc_zones_file" ]]; then
        echo "  - ${dlc_prefix}_zones.xml"
        process_zones_file "$dlc_zones_file" "${DLC_OUT}/${dlc_prefix}_zones.xml"
        dlc_file_count=$((dlc_file_count + 1))
    fi
    
    dlc_sectors_file="${DLC_SRC}/${dlc_prefix}_sectors.xml"
    if [[ -f "$dlc_sectors_file" ]]; then
        echo "  - ${dlc_prefix}_sectors.xml"
        zones_ref=""
        [[ -f "$dlc_zones_file" ]] && zones_ref="$dlc_zones_file"
        process_sectors_file "$dlc_sectors_file" "${DLC_OUT}/${dlc_prefix}_sectors.xml" "$zones_ref"
        dlc_file_count=$((dlc_file_count + 1))
    fi

    # Process god.xml for DLC
    dlc_god_file="${DLC_SRC_DIR}/${dlc_name}/libraries/god.xml"
    if [[ -f "$dlc_god_file" ]]; then
        echo "  - god.xml"
        mkdir -p "${DLC_OUT_DIR}/${dlc_name}/libraries"
        sectors_ref=""
        zones_ref=""
        [[ -f "$dlc_sectors_file" ]] && sectors_ref="$dlc_sectors_file"
        [[ -f "$dlc_zones_file" ]] && zones_ref="$dlc_zones_file"
        process_god_file "$dlc_god_file" "${DLC_OUT_DIR}/${dlc_name}/libraries/god.xml" "$sectors_ref" "$zones_ref"
        dlc_file_count=$((dlc_file_count + 1))
    fi

    echo ""
done

echo "=========================================="
echo "Generation Complete"
echo "=========================================="
echo ""

echo "Output Location: ${VANILLA_OUT}/"
echo "Factor Applied: ${FACTOR}x"
echo "Highways Removed: $([ $NO_HIGHWAYS -eq 1 ] && echo "YES" || echo "NO")"
echo ""

echo "SUCCESS - All XML diff patches generated"