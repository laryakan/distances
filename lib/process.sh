#!/bin/bash
# Distances Mod - Thin bash wrappers around the AWK generators.
#
# All position math (scaling, clamping, zero-axis jitter, protected-zone
# reparenting) lives in lib/awk/*.awk. These functions just wire the right
# files/parameters together and write the resulting diff patch.

AWK_DIR="${AWK_DIR:-${SCRIPT_DIR}/lib/awk}"
COMMON_AWK="${AWK_DIR}/common.awk"

# process_sectors_file <input sectors.xml> <output diff> [zones.xml]
process_sectors_file() {
    local input_file="$1"
    local output_file="$2"
    local zones_file="${3:-}"
    local zones_arg=()

    if [[ -n "$zones_file" && -f "$zones_file" ]]; then
        zones_arg=("$zones_file")
    fi

    {
        echo '<?xml version="1.0" encoding="utf-8"?>'
        echo '<!-- Distances Mod - Generated -->'
        echo '<diff>'
        awk -f "$COMMON_AWK" -f "${AWK_DIR}/emit_sectors.awk" \
            -v factor="$FACTOR" \
            -v exclude="$exclude_pattern" \
            -v no_highways="$NO_HIGHWAYS" \
            -v extra_mult_a="$EXTRA_RESOURCE_ZONE_MULT" \
            -v extra_mult_b="$EXTRA_RESOURCE_ZONE_MULT_2" \
            -v phase_a="$EXTRA_PHASE_A" \
            -v phase_b="$EXTRA_PHASE_B" \
            -v radius_floor="$MAX_SECTOR_RADIUS" \
            -v radius_headroom="$NATURAL_RADIUS_HEADROOM" \
            -v radius_safety="$SAFETY_MAX_RADIUS" \
            -v clamp_margin="$CLAMP_MARGIN" \
            -v jitter_frac="$JITTER_FRACTION" \
            -v jitter_minabs="$JITTER_MIN_ABS" \
            -v zones_file="$zones_file" \
            -v sectors_file="$input_file" \
            "${zones_arg[@]}" "$input_file" "$input_file"
        echo '</diff>'
    } > "$output_file"
}

# process_zones_file <input zones.xml> <output diff>
process_zones_file() {
    local input_file="$1"
    local output_file="$2"

    {
        echo '<?xml version="1.0" encoding="utf-8"?>'
        echo '<!-- Distances Mod - Resource Zones Added -->'
        echo '<diff>'
        awk -f "$COMMON_AWK" -f "${AWK_DIR}/emit_zones.awk" \
            -v factor="$FACTOR" \
            -v no_highways="$NO_HIGHWAYS" \
            -v exclude="$exclude_pattern" \
            -v maxr="$MAX_SECTOR_RADIUS" \
            -v clamp_margin="$CLAMP_MARGIN" \
            -v jitter_frac="$JITTER_FRACTION" \
            -v jitter_minabs="$JITTER_MIN_ABS" \
            "$input_file"
        echo '</diff>'
    } > "$output_file"
}

# process_god_file <input god.xml> <output diff> [sectors.xml] [zones.xml]
process_god_file() {
    local input_file="$1"
    local output_file="$2"
    local sectors_file="${3:-}"
    local zones_file="${4:-}"
    local sectors_scan="${sectors_file:-/dev/null}"
    local zones_scan="${zones_file:-/dev/null}"

    {
        echo '<?xml version="1.0" encoding="utf-8"?>'
        echo '<!-- Distances Mod - GOD fixed-position scaling -->'
        echo '<diff>'
        awk -f "$COMMON_AWK" -f "${AWK_DIR}/emit_god.awk" \
            -v exclude="$exclude_pattern" \
            -v exclude_keywords="$EXCLUDE_NON_OPEN_WORLD_REGEX" \
            -v factor="$FACTOR" \
            -v radius_floor="$MAX_SECTOR_RADIUS" \
            -v radius_headroom="$NATURAL_RADIUS_HEADROOM" \
            -v radius_safety="$SAFETY_MAX_RADIUS" \
            -v clamp_margin="$CLAMP_MARGIN" \
            -v jitter_frac="$JITTER_FRACTION" \
            -v jitter_minabs="$JITTER_MIN_ABS" \
            -v sectors_file="$sectors_scan" \
            -v zones_file="$zones_scan" \
            "$sectors_scan" "$zones_scan" "$input_file"
        echo '</diff>'
    } > "$output_file"
}
