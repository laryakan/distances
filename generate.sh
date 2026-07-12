#!/bin/bash
#
# Distances Mod - Generate Script
# Transforms vanilla sectors.xml by multiplying zone distances
#
# Usage:
#   ./generate.sh [factor]
#
# Examples:
#   ./generate.sh           # Interactive prompt
#   ./generate.sh 2.0       # 2x distance
#   ./generate.sh 3.5       # 3.5x distance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VANILLA_SECTORS="${SCRIPT_DIR}/_default/maps/xu_ep2_universe/sectors.xml"
VANILLA_ZONES="${SCRIPT_DIR}/_default/maps/xu_ep2_universe/zones.xml"
VANILLA_GOD="${SCRIPT_DIR}/_default/libraries/god.xml"
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
    echo "Error: Vanilla file not found: $VANILLA_SECTORS" >&2
    echo "Please run: cd /path/to/X4 && bash extensions/Distances/extract_default.sh" >&2
    exit 1
fi

if [[ ! -f "$VANILLA_ZONES" ]]; then
    echo "Warning: zones.xml not found: $VANILLA_ZONES" >&2
fi

# Hazard sectors to exclude from modifications.
# Keep fixed placements in sectors with damage/tide mechanics.
EXCLUDE_SECTORS=(
    "[Cc]luster_27_[Ss]ector001_macro"  # The Void
    "[Cc]luster_605_[Ss]ector001_macro" # Sanctuary of Darkness
    "[Cc]luster_500_[Ss]ector001_macro" # Avarice
    "[Cc]luster_500_[Ss]ector002_macro" # Avarice
    "[Cc]luster_500_[Ss]ector003_macro" # Avarice
)

echo "Generating with factor $FACTOR..."
echo "Excluding hazard sectors..."
echo ""

# Purge previously generated files
echo "Cleaning up old generated files..."
rm -f "${SCRIPT_DIR}/maps/xu_ep2_universe"/*.xml 2>/dev/null || true
rm -f "${SCRIPT_DIR}/libraries/god.xml" 2>/dev/null || true
find "${SCRIPT_DIR}/extensions"/ego_dlc_*/maps/xu_ep2_universe -name "*.xml" -type f -delete 2>/dev/null || true
find "${SCRIPT_DIR}/extensions"/ego_dlc_*/libraries -name "god.xml" -type f -delete 2>/dev/null || true
echo ""

# Build exclusion pattern
exclude_pattern=""
for sector in "${EXCLUDE_SECTORS[@]}"; do
    if [[ -z "$exclude_pattern" ]]; then
        exclude_pattern="$sector"
    else
        exclude_pattern="${exclude_pattern}|${sector}"
    fi
done

# Process all sectors.xml and zones.xml files (base game + DLC)
total_sectors_modified=0
total_zones_modified=0
total_resource_zones_added=0
total_god_positions_modified=0
EXTRA_RESOURCE_ZONE_MULT=1.35
EXTRA_RESOURCE_ZONE_MULT_2=1.7
MAX_SECTOR_RADIUS=180000
CLAMP_MARGIN=0.98
EXTRA_PHASE_A=0.04
EXTRA_PHASE_B=-0.04
# Additional distance multiplier for non-travel objects in sectors that contain highways.
# Helps rebalance "favored" sectors while still leaving gates/highways untouched.
HIGHWAY_SECTOR_BONUS=1.2

# Clamp X/Z to a safe radius from sector center.
# Optional phase (radians) spreads points tangentially to reduce overlap.
clamp_xz() {
    local x="$1"
    local z="$2"
    local phase="${3:-0}"

    awk -v x="$x" -v z="$z" -v maxr="$MAX_SECTOR_RADIUS" -v margin="$CLAMP_MARGIN" -v phase="$phase" '
    BEGIN {
        r = sqrt((x * x) + (z * z))
        if (r == 0) {
            print "0|0|0"
            exit
        }

        # Apply phase for deterministic spread (mainly for added resource zones).
        theta = atan2(z, x) + phase

        # Keep positions under hard limit, with a tiny margin for safety.
        rr = r
        clamped = 0
        if (rr > maxr) {
            rr = maxr * margin
            clamped = 1
        }

        nx = rr * cos(theta)
        nz = rr * sin(theta)
        print nx "|" nz "|" clamped
    }'
}

get_dlc_map_prefix() {
    local dlc_name="$1"

    case "$dlc_name" in
        ego_dlc_split) echo "dlc4" ;;
        ego_dlc_timelines) echo "dlc7" ;;
        *) echo "${dlc_name#ego_}" ;;
    esac
}

process_sectors_file() {
    local input_file="$1"
    local output_file="$2"
    local zones_file="${3:-}"
    local protected_zones=""
    local resource_zones=""
    local zone_macros=""

    # Build a list of zone macros that are part of the travel network.
    # Those zones must not have their sector offsets changed.
    if [[ -n "$zones_file" && -f "$zones_file" ]]; then
        protected_zones=$(awk '
        /<macro name="[^"]*" class="zone">/ {
            match($0, /name="([^"]*)"/, arr)
            current_zone = arr[1]
            if (index(current_zone, "SHCon") > 0) protected[current_zone] = 1
        }
        /<connection / && current_zone {
            # Gate zones must stay fixed to avoid highway/gate desync.
            if (index($0, "ref=\"gates\"") > 0) protected[current_zone] = 1
        }
        END {
            first = 1
            for (z in protected) {
                if (!first) printf("|")
                printf("%s", z)
                first = 0
            }
        }
        ' "$zones_file")

        resource_zones=$(awk '
        /<macro name="[^"]*" class="zone">/ {
            match($0, /name="([^"]*)"/, arr)
            current_zone = arr[1]
            is_resource = 0
        }
        /<connection / && current_zone {
            line = tolower($0)
            is_travel = 0
            if (index(line, "ref=\"gates\"") > 0) is_travel = 1
            if (index(line, "highway") > 0) is_travel = 1
            if (index(line, "_gate\"") > 0) is_travel = 1
            if (index(line, "clustergate") > 0) is_travel = 1
            if (!is_travel) is_resource = 1

            if (index(line, "ref=\"asteroids\"") > 0) is_resource = 1
            if (index(line, "asteroid") > 0) is_resource = 1
            if (index(line, "resource") > 0) is_resource = 1
            if (index(line, "ore") > 0) is_resource = 1
            if (index(line, "silicon") > 0) is_resource = 1
            if (index(line, "ice") > 0) is_resource = 1
            if (index(line, "gas") > 0) is_resource = 1
            if (index(line, "hydrogen") > 0) is_resource = 1
            if (index(line, "helium") > 0) is_resource = 1
            if (index(line, "methane") > 0) is_resource = 1
            if (index(line, "nividium") > 0) is_resource = 1
            if (index(line, "nebula") > 0) is_resource = 1
            if (index(line, "fog") > 0) is_resource = 1
            if (index(line, "debris") > 0) is_resource = 1
        }
        /<macro ref="[^"]*"/ && current_zone {
            line = tolower($0)
            if (index(line, "asteroid") > 0) is_resource = 1
            if (index(line, "ore") > 0) is_resource = 1
            if (index(line, "silicon") > 0) is_resource = 1
            if (index(line, "ice") > 0) is_resource = 1
            if (index(line, "gas") > 0) is_resource = 1
            if (index(line, "hydrogen") > 0) is_resource = 1
            if (index(line, "helium") > 0) is_resource = 1
            if (index(line, "methane") > 0) is_resource = 1
            if (index(line, "nividium") > 0) is_resource = 1
            if (index(line, "nebula") > 0) is_resource = 1
            if (index(line, "fog") > 0) is_resource = 1
            if (index(line, "debris") > 0) is_resource = 1
        }
        /<\/macro>/ && current_zone {
            if (is_resource) resource[current_zone] = 1
            current_zone = ""
        }
        END {
            first = 1
            for (z in resource) {
                if (!first) printf("|")
                printf("%s", z)
                first = 0
            }
        }
        ' "$zones_file")

        zone_macros=$(awk '
        /<macro name="[^"]*" class="zone">/ {
            match($0, /name="([^"]*)"/, arr)
            zones[arr[1]] = 1
        }
        END {
            first = 1
            for (z in zones) {
                if (!first) printf("|")
                printf("%s", z)
                first = 0
            }
        }
        ' "$zones_file")
    fi
    
    {
        echo '<?xml version="1.0" encoding="utf-8"?>'
        echo '<!-- Distances Mod - Generated -->'
        echo '<diff>'
        
        # Extract all position lines with their context
        awk -v exclude="$exclude_pattern" -v protected="$protected_zones" -v resources="$resource_zones" -v zonemacros="$zone_macros" '
        BEGIN {
            current_macro = ""
            current_connection = ""
            current_zone_ref = ""
            pending_x = ""
            pending_y = ""
            pending_z = ""
            if (protected != "") {
                split(protected, p, "|")
                for (i in p) {
                    if (p[i] != "") protected_map[p[i]] = 1
                }
            }
            if (resources != "") {
                split(resources, r, "|")
                for (i in r) {
                    if (r[i] != "") resource_map[r[i]] = 1
                }
            }
            if (zonemacros != "") {
                split(zonemacros, z, "|")
                for (i in z) {
                    if (z[i] != "") zone_map[z[i]] = 1
                }
            }
        }
        FNR == NR {
            if ($0 ~ /<macro name="[^"]*" class="sector">/) {
                match($0, /name="([^"]*)"/, s_arr)
                sector_macro = s_arr[1]
            }
            if (sector_macro != "" && $0 ~ /<connection /) {
                if (index($0, "Highway") > 0 || index($0, "ref=\"zonehighways\"") > 0) {
                    highway_sector[sector_macro] = 1
                }
            }
            next
        }
        /<macro name="[^"]*" class="sector">/ {
            match($0, /name="([^"]*)"/, arr)
            current_macro = arr[1]
        }
        /<connection name="([^"]*)"/ {
            match($0, /name="([^"]*)"/, arr)
            current_connection = arr[1]
            current_zone_ref = ""
            pending_x = ""
            pending_y = ""
            pending_z = ""
        }
        /<position x=/ && current_macro && current_connection {
            match($0, /x="([^"]*)"/, x_arr)
            match($0, /y="([^"]*)"/, y_arr)
            match($0, /z="([^"]*)"/, z_arr)

            pending_x = x_arr[1]
            pending_y = y_arr[1]
            pending_z = z_arr[1]
        }
        /<macro ref="[^"]*" connection="sector"/ && current_macro && current_connection {
            match($0, /ref="([^"]*)"/, ref_arr)
            current_zone_ref = ref_arr[1]

            # Skip if sector macro is in exclude list.
            if (exclude != "" && match(current_macro, exclude)) next

            # Keep travel network intact: skip gate zones/highways by connection naming.
            if (index(current_connection, "SHCon") > 0) next
            if (index(current_connection, "Highway") > 0) next

            # Only process refs that are actual zone macros, never highway macros.
            if (!(current_zone_ref in zone_map)) next

            # Keep travel network intact: skip zones containing gates/highway endpoints.
            if (current_zone_ref in protected_map) next

            if (pending_x != "" && pending_y != "" && pending_z != "") {
                is_resource = (current_zone_ref in resource_map) ? 1 : 0
                has_highway = (current_macro in highway_sector) ? 1 : 0
                print current_macro "|" current_connection "|" pending_x "|" pending_y "|" pending_z "|" current_zone_ref "|" is_resource "|" has_highway
            }
        }
        ' "$input_file" "$input_file" | while IFS='|' read -r macro conn x y z zone_ref is_resource has_highway; do
            # Calculate new coordinates using bc for floating point
            effective_factor="$FACTOR"
            if [[ "$has_highway" == "1" ]]; then
                effective_factor=$(echo "$FACTOR * $HIGHWAY_SECTOR_BONUS" | bc)
            fi

            new_x=$(echo "$x * $effective_factor" | bc)
            new_z=$(echo "$z * $effective_factor" | bc)

            clamped_main=$(clamp_xz "$new_x" "$new_z")
            IFS='|' read -r new_x new_z _ <<< "$clamped_main"
            
            # Generate diff entry
            sel="/macros/macro[@name='$macro']/connections/connection[@name='$conn']/offset/position"
            
            echo "  <replace sel=\"$sel\">"
            echo "    <position x=\"$new_x\" y=\"$y\" z=\"$new_z\" />"
            echo "  </replace>"

            # Add farther extra zone instances for logistics:
            # - all eligible non-travel zones get one extra
            # - resource-tagged zones get a second extra
            if [[ -n "$zone_ref" ]]; then
                extra_x=$(echo "$new_x * $EXTRA_RESOURCE_ZONE_MULT" | bc)
                extra_z=$(echo "$new_z * $EXTRA_RESOURCE_ZONE_MULT" | bc)
                extra_x2=$(echo "$new_x * $EXTRA_RESOURCE_ZONE_MULT_2" | bc)
                extra_z2=$(echo "$new_z * $EXTRA_RESOURCE_ZONE_MULT_2" | bc)
                extra_conn="${conn}_resourceextra_a"
                extra_conn2="${conn}_resourceextra_b"

                clamped_a=$(clamp_xz "$extra_x" "$extra_z" "$EXTRA_PHASE_A")
                IFS='|' read -r extra_x extra_z _ <<< "$clamped_a"
                clamped_b=$(clamp_xz "$extra_x2" "$extra_z2" "$EXTRA_PHASE_B")
                IFS='|' read -r extra_x2 extra_z2 _ <<< "$clamped_b"

                add_sel="/macros/macro[@name='$macro']/connections"
                echo "  <add sel=\"$add_sel\">"
                echo "    <connection name=\"$extra_conn\" ref=\"zones\">"
                echo "      <offset>"
                echo "        <position x=\"$extra_x\" y=\"$y\" z=\"$extra_z\" />"
                echo "      </offset>"
                echo "      <macro ref=\"$zone_ref\" connection=\"sector\" />"
                echo "    </connection>"
                echo "  </add>"

                if [[ "$is_resource" == "1" ]]; then
                    echo "  <add sel=\"$add_sel\">"
                    echo "    <connection name=\"$extra_conn2\" ref=\"zones\">"
                    echo "      <offset>"
                    echo "        <position x=\"$extra_x2\" y=\"$y\" z=\"$extra_z2\" />"
                    echo "      </offset>"
                    echo "      <macro ref=\"$zone_ref\" connection=\"sector\" />"
                    echo "    </connection>"
                    echo "  </add>"
                fi
            fi
        done
        
        echo '</diff>'
        
    } > "$output_file"
}

process_zones_file() {
    local input_file="$1"
    local output_file="$2"
    
    {
        echo '<?xml version="1.0" encoding="utf-8"?>'
        echo '<!-- Distances Mod - Resource Zones Added -->'
        echo '<diff>'
        
        # Extract zone macro connection positions from actual zones.xml structure.
        awk -v factor="$FACTOR" -v maxr="$MAX_SECTOR_RADIUS" -v margin="$CLAMP_MARGIN" '
        BEGIN {
            current_macro = ""
            current_conn_name = ""
            current_conn_ref = ""
        }
        /<macro name="[^"]*" class="zone">/ {
            match($0, /name="([^"]*)"/, arr)
            current_macro = arr[1]
        }
        /<connection / {
            current_conn_name = ""
            current_conn_ref = ""
            if (match($0, /name="([^"]*)"/, n_arr)) current_conn_name = n_arr[1]
            if (match($0, /ref="([^"]*)"/, r_arr)) current_conn_ref = r_arr[1]
        }
        /<position x=/ && current_macro {
            # Ignore gate-only SHCon zone macros to avoid touching critical travel links.
            if (index(current_macro, "SHCon") > 0) next

            # Ignore highway gate endpoints in zones to keep highway topology stable.
            if (index(current_conn_name, "Highway") > 0) next
            if (index(current_conn_ref, "Highway") > 0) next

            # Ignore gate connections too, otherwise gates move while highways stay put.
            if (current_conn_ref == "gates") next
            if (index(current_conn_name, "Gate") > 0) next
            if (index(current_conn_ref, "gate") > 0) next

            match($0, /x="([^"]*)"/, x_arr)
            match($0, /y="([^"]*)"/, y_arr)
            match($0, /z="([^"]*)"/, z_arr)

            x = x_arr[1]
            y = y_arr[1]
            z = z_arr[1]

            if (x != "" && y != "" && z != "") {
                new_x = x * factor
                new_z = z * factor

                r = sqrt((new_x * new_x) + (new_z * new_z))
                if (r > maxr && r > 0) {
                    scale = (maxr * margin) / r
                    new_x = new_x * scale
                    new_z = new_z * scale
                }

                if (current_conn_name != "") {
                    sel = "/macros/macro[@name='\''" current_macro "'\'']/connections/connection[@name='\''" current_conn_name "'\'']/offset/position"
                } else if (current_conn_ref != "") {
                    sel = "/macros/macro[@name='\''" current_macro "'\'']/connections/connection[@ref='\''" current_conn_ref "'\'']/offset/position"
                } else {
                    next
                }

                print "  <replace sel=\"" sel "\">"
                print "    <position x=\"" new_x "\" y=\"" y "\" z=\"" new_z "\" />"
                print "  </replace>"
            }
        }
        ' "$input_file" | while IFS= read -r line; do
            [[ -n "$line" ]] && echo "$line"
        done
        
        echo '</diff>'
        
    } > "$output_file"
}

process_god_file() {
    local input_file="$1"
    local output_file="$2"

    {
        echo '<?xml version="1.0" encoding="utf-8"?>'
        echo '<!-- Distances Mod - GOD fixed-position scaling -->'
        echo '<diff>'

        awk -v exclude="$exclude_pattern" '
        BEGIN {
            in_gamestart = 0
            gamestart_ref = ""
            section = ""
            current_station = ""
            current_object = ""
            current_location_macro = ""
        }
        /<gamestart ref="[^"]*"/ {
            in_gamestart = 1
            if (match($0, /ref="([^"]*)"/, arr)) gamestart_ref = arr[1]
        }
        /<\/gamestart>/ {
            in_gamestart = 0
            gamestart_ref = ""
            section = ""
            current_station = ""
            current_object = ""
        }
        /<stations>/ { section = "stations" }
        /<\/stations>/ {
            if (section == "stations") {
                section = ""
                current_station = ""
                current_location_macro = ""
            }
        }
        /<objects>/ { section = "objects" }
        /<\/objects>/ {
            if (section == "objects") {
                section = ""
                current_object = ""
                current_location_macro = ""
            }
        }
        /<station id="[^"]*"/ {
            if (match($0, /id="([^"]*)"/, arr)) current_station = arr[1]
            current_location_macro = ""
        }
        /<\/station>/ {
            current_station = ""
            current_location_macro = ""
        }
        /<object id="[^"]*"/ {
            if (match($0, /id="([^"]*)"/, arr)) current_object = arr[1]
            current_location_macro = ""
        }
        /<\/object>/ {
            current_object = ""
            current_location_macro = ""
        }
        /<location class="(zone|sector)"/ {
            if (match($0, /macro="([^"]*)"/, l_arr)) current_location_macro = l_arr[1]
        }
        /<position x=/ {
            x = ""
            y = ""
            z = ""
            yaw = ""
            pitch = ""
            roll = ""

            # Keep same exclusion behavior as sector/zones processing.
            if (exclude != "" && current_location_macro != "" && match(current_location_macro, exclude)) next

            if (match($0, /x="([^"]*)"/, ax)) x = ax[1]
            if (match($0, /y="([^"]*)"/, ay)) y = ay[1]
            if (match($0, /z="([^"]*)"/, az)) z = az[1]
            if (x == "" || z == "") next

            # Skip entries that are not plain numeric coordinates.
            if (x !~ /^[-+]?[0-9]*\.?[0-9]+$/) next
            if (z !~ /^[-+]?[0-9]*\.?[0-9]+$/) next

            if (match($0, /yaw="([^"]*)"/, aw)) yaw = aw[1]
            if (match($0, /pitch="([^"]*)"/, ap)) pitch = ap[1]
            if (match($0, /roll="([^"]*)"/, ar)) roll = ar[1]

            sel = ""
            if (current_station != "") {
                if (in_gamestart && gamestart_ref != "") {
                    sel = "/god/gamestart[@ref='\''" gamestart_ref "'\'']/stations/station[@id='\''" current_station "'\'']/position"
                } else {
                    sel = "/god/stations/station[@id='\''" current_station "'\'']/position"
                }
            } else if (current_object != "") {
                if (in_gamestart && gamestart_ref != "") {
                    sel = "/god/gamestart[@ref='\''" gamestart_ref "'\'']/objects/object[@id='\''" current_object "'\'']/position"
                } else {
                    sel = "/god/objects/object[@id='\''" current_object "'\'']/position"
                }
            }

            if (sel != "") {
                print sel "\t" x "\t" y "\t" z "\t" yaw "\t" pitch "\t" roll
            }
        }
        ' "$input_file" | while IFS=$'\t' read -r sel x y z yaw pitch roll; do
            new_x=$(awk -v v="$x" -v f="$FACTOR" 'BEGIN { print (v * f) }')
            new_z=$(awk -v v="$z" -v f="$FACTOR" 'BEGIN { print (v * f) }')

            clamped_main=$(clamp_xz "$new_x" "$new_z")
            IFS='|' read -r new_x new_z _ <<< "$clamped_main"

            y_out="$y"
            if [[ -z "$y_out" ]]; then
                y_out="0"
            fi

            extra_attrs=""
            if [[ -n "$pitch" ]]; then
                extra_attrs+=" pitch=\"$pitch\""
            fi
            if [[ -n "$roll" ]]; then
                extra_attrs+=" roll=\"$roll\""
            fi
            if [[ -n "$yaw" ]]; then
                extra_attrs+=" yaw=\"$yaw\""
            fi

            echo "  <replace sel=\"$sel\">"
            echo "    <position x=\"$new_x\" y=\"$y_out\" z=\"$new_z\"$extra_attrs />"
            echo "  </replace>"
        done

        echo '</diff>'
    } > "$output_file"
}

# Process base game sectors
if [[ -f "$VANILLA_SECTORS" ]]; then
    mkdir -p "$(dirname "$OUTPUT_SECTORS")"
    process_sectors_file "$VANILLA_SECTORS" "$OUTPUT_SECTORS" "$VANILLA_ZONES"
    modified=$(awk '/<position x=/{c++} END{print c+0}' "$OUTPUT_SECTORS")
    added=$(awk '/_resourceextra/{c++} END{print c+0}' "$OUTPUT_SECTORS")
    total_sectors_modified=$((total_sectors_modified + modified))
    total_resource_zones_added=$((total_resource_zones_added + added))
    echo "✓ Base game sectors: $modified positions"
    echo "✓ Base game extra resource zones: $added"
fi

# Process base game zones
if [[ -f "$VANILLA_ZONES" ]]; then
    mkdir -p "$(dirname "$OUTPUT_ZONES")"
    process_zones_file "$VANILLA_ZONES" "$OUTPUT_ZONES"
    modified=$(awk '/<replace sel=/{c++} END{print c+0}' "$OUTPUT_ZONES")
    total_zones_modified=$((total_zones_modified + modified))
    echo "✓ Base game zones: $modified zones repositioned"
    if (( modified == 0 )); then
        echo "⚠ Base game zones: no matching zone entries found for current parser"
    fi
else
    echo "⚠ Base game zones.xml not found, skipping..."
fi

# Process base game GOD
if [[ -f "$VANILLA_GOD" ]]; then
    mkdir -p "$(dirname "$OUTPUT_GOD")"
    process_god_file "$VANILLA_GOD" "$OUTPUT_GOD"
    modified=$(awk '/<replace sel=/{c++} END{print c+0}' "$OUTPUT_GOD")
    total_god_positions_modified=$((total_god_positions_modified + modified))
    echo "✓ Base game GOD: $modified fixed positions"
else
    echo "⚠ Base game god.xml not found, skipping..."
fi

echo ""
echo "Processing DLC extensions..."
echo ""

# Process DLC sectors and zones
if [[ -d "${SCRIPT_DIR}/_default/extensions" ]]; then
    for dlc_dir in "${SCRIPT_DIR}"/_default/extensions/ego_dlc_*; do
        if [[ -d "$dlc_dir" ]]; then
            dlc_name=$(basename "$dlc_dir")
            dlc_prefix=$(get_dlc_map_prefix "$dlc_name")

            if [[ ! -f "${dlc_dir}/maps/xu_ep2_universe/${dlc_prefix}_sectors.xml" ]]; then
                detected_file=$(find "${dlc_dir}/maps/xu_ep2_universe" -maxdepth 1 -type f -name "*_sectors.xml" 2>/dev/null | head -n 1)
                if [[ -n "$detected_file" ]]; then
                    dlc_prefix=$(basename "$detected_file")
                    dlc_prefix="${dlc_prefix%_sectors.xml}"
                fi
            fi
            
            dlc_sectors="${dlc_dir}/maps/xu_ep2_universe/${dlc_prefix}_sectors.xml"
            dlc_zones="${dlc_dir}/maps/xu_ep2_universe/${dlc_prefix}_zones.xml"
            dlc_god="${dlc_dir}/libraries/god.xml"
            
            if [[ -f "$dlc_sectors" ]]; then
                dlc_sectors_output="${SCRIPT_DIR}/extensions/${dlc_name}/maps/xu_ep2_universe/${dlc_prefix}_sectors.xml"
                dlc_zones_output="${SCRIPT_DIR}/extensions/${dlc_name}/maps/xu_ep2_universe/${dlc_prefix}_zones.xml"
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
                    process_god_file "$dlc_god" "$dlc_god_output"
                    god_modified=$(awk '/<replace sel=/{c++} END{print c+0}' "$dlc_god_output")
                    total_god_positions_modified=$((total_god_positions_modified + god_modified))
                fi
                
                if (( sectors_modified > 0 || zones_modified > 0 || god_modified > 0 )); then
                    echo "✓ $dlc_name: $sectors_modified sectors, $zones_modified zones, $god_modified GOD fixed positions, $added extra resource zones"
                fi
            else
                echo "⚠ $dlc_name: sectors file not found"
            fi
        fi
    done
else
    echo "⚠ No DLC extensions directory found"
fi

# Summary
excluded_count=${#EXCLUDE_SECTORS[@]}

echo ""
echo "========================================="
echo "✓ Generation completed!"
echo "  Sector positions: $total_sectors_modified"
echo "  Resource zones: $total_zones_modified"
echo "  GOD fixed positions: $total_god_positions_modified"
echo "  Extra resource zones added: $total_resource_zones_added"
echo "  Sectors excluded: $excluded_count"
echo "  Factor: ${FACTOR}x"
echo "========================================="
