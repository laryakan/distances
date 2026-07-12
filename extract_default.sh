#!/bin/bash

# Extraction of Distances Mod "_default" vanilla files from X4: Foundations
# Place this script at the root of a CAT extraction from "X4: Foundations"
# For extraction of assets from Vanilla version and official DLC extensions
# use the following commands with XRCatTool (Windows cmd) :
# for %f in ("F:\Games\X4 Foundations\*.cat") do XRCatTool.exe -in "%f" -out "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0" 
# md "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0\extensions
# md "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0\extensions\ego_dlc_timelines"
# for %f in ("F:\Games\X4 Foundations\extensions\ego_dlc_timelines\*.cat") do XRCatTool.exe -in "%f" -out "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0\extensions\ego_dlc_timelines" 
# md "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0\extensions\ego_dlc_boron"
# for %f in ("F:\Games\X4 Foundations\extensions\ego_dlc_boron\*.cat") do XRCatTool.exe -in "%f" -out "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0\extensions\ego_dlc_boron" 
# md "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0\extensions\ego_dlc_pirate"
# for %f in ("F:\Games\X4 Foundations\extensions\ego_dlc_pirate\*.cat") do XRCatTool.exe -in "%f" -out "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0\extensions\ego_dlc_pirate" 
# md "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0\extensions\ego_dlc_split"
# for %f in ("F:\Games\X4 Foundations\extensions\ego_dlc_split\*.cat") do XRCatTool.exe -in "%f" -out "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0\extensions\ego_dlc_split" 
# md "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0\extensions\ego_dlc_terran"
# for %f in ("F:\Games\X4 Foundations\extensions\ego_dlc_terran\*.cat") do XRCatTool.exe -in "%f" -out "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0\extensions\ego_dlc_terran" 
# md "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0\extensions\ego_dlc_mini_01"
# for %f in ("F:\Games\X4 Foundations\extensions\ego_dlc_mini_01\*.cat") do XRCatTool.exe -in "%f" -out "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0\extensions\ego_dlc_mini_01"
# md "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0\extensions\ego_dlc_mini_02"
# for %f in ("F:\Games\X4 Foundations\extensions\ego_dlc_mini_02\*.cat") do XRCatTool.exe -in "%f" -out "S:\users\paulw\downloads\x4\XTools_1.11\extracts\x4_9.0\extensions\ego_dlc_mini_02"
#
# Usage:
#   cd /path/to/X4\ Foundations
#   bash extract_default.sh
#
# This will copy vanilla sectors.xml from the game to:
#   extensions/Distances/_default/maps/xu_ep2_universe/sectors.xml

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
OUTPUT_DIR="_default"

mkdir -p "$SCRIPT_DIR/$OUTPUT_DIR"

copy_files() {
    local src_dir="$1"
    local pattern="$2"
    local dest_subdir="$3"
    local message="$4"
    
    if [[ -d "$src_dir" ]]; then
        echo "  → $message..."
        for file in "$src_dir"/$pattern; do
            if [[ -f "$file" ]]; then
                mkdir -p "$SCRIPT_DIR/$OUTPUT_DIR/$dest_subdir"
                cp "$file" "$SCRIPT_DIR/$OUTPUT_DIR/$dest_subdir/"
            fi
        done
    fi
}

get_dlc_map_prefix() {
    local dlc_name="$1"

    case "$dlc_name" in
        ego_dlc_split) echo "dlc4" ;;
        ego_dlc_timelines) echo "dlc7" ;;
        *) echo "${dlc_name#ego_}" ;;
    esac
}

echo "Extracting vanilla files for Distances Mod..."
echo ""

# Main game files
copy_files "$SCRIPT_DIR/maps/xu_ep2_universe" "sectors.xml" "maps/xu_ep2_universe" "Copying sectors.xml"
copy_files "$SCRIPT_DIR/maps/xu_ep2_universe" "zones.xml" "maps/xu_ep2_universe" "Copying zones.xml"
copy_files "$SCRIPT_DIR/maps/xu_ep2_universe" "sechighways.xml" "maps/xu_ep2_universe" "Copying sechighways.xml"
copy_files "$SCRIPT_DIR/libraries" "god.xml" "libraries" "Copying god.xml"

# Official DLC extensions (in case they have sector modifications in future)
for dlc_dir in "$SCRIPT_DIR/extensions"/ego_dlc_*; do
    if [[ -d "$dlc_dir" ]]; then
        dlc_name=$(basename "$dlc_dir")
        # Resolve map prefix (special cases: split=dlc4, timelines=dlc7).
        dlc_prefix=$(get_dlc_map_prefix "$dlc_name")
        
        if [[ -d "$dlc_dir/maps/xu_ep2_universe" ]]; then
            echo "Processing $dlc_name..."
            if [[ ! -f "$dlc_dir/maps/xu_ep2_universe/${dlc_prefix}_sectors.xml" ]]; then
                detected_file=$(find "$dlc_dir/maps/xu_ep2_universe" -maxdepth 1 -type f -name "*_sectors.xml" | head -n 1)
                if [[ -n "$detected_file" ]]; then
                    dlc_prefix=$(basename "$detected_file")
                    dlc_prefix="${dlc_prefix%_sectors.xml}"
                    echo "  → Auto-detected map prefix: $dlc_prefix"
                fi
            fi
            # DLC files have prefix (e.g., dlc_boron_sectors.xml)
            copy_files "$dlc_dir/maps/xu_ep2_universe" "${dlc_prefix}_sectors.xml" "extensions/$dlc_name/maps/xu_ep2_universe" "Copying ${dlc_prefix}_sectors.xml"
            copy_files "$dlc_dir/maps/xu_ep2_universe" "${dlc_prefix}_zones.xml" "extensions/$dlc_name/maps/xu_ep2_universe" "Copying ${dlc_prefix}_zones.xml"
        fi

        if [[ -d "$dlc_dir/libraries" ]]; then
            copy_files "$dlc_dir/libraries" "god.xml" "extensions/$dlc_name/libraries" "Copying god.xml"
        fi
    fi
done

echo ""
echo "Converting line endings to LF..."
find "$SCRIPT_DIR/$OUTPUT_DIR" -type f -name "*.xml" -exec dos2unix {} \; 2> /dev/null || \
find "$SCRIPT_DIR/$OUTPUT_DIR" -type f -name "*.xml" -exec sed -i 's/\r$//' {} \;

echo ""
echo "✓ Extraction completed!"
echo "  Files copied to: $OUTPUT_DIR/"
echo ""
echo "Next step:"
echo "  cd extensions/Distances"
echo "  bash generate.sh"
