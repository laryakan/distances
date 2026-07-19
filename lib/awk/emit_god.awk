# emit_god.awk - Generates the <diff> body for a god.xml file.
# Requires common.awk loaded first.
#
# Expected invocation (see lib/process.sh):
#   awk -f common.awk -f emit_god.awk -v ... -v sectors_file=S -v zones_file=Z \
#       S Z god.xml
# (S and/or Z can be /dev/null if absent.)
#
# Special case: stations/objects located in a "protected" zone (SHCon or
# gate zone) must not see their host zone moved (travel network integrity).
# If that zone is also small, the station barely moves with the factor.
#
# Two rules apply to these fixed positions:
# - Defense stations (id contains "defence"/"defense") guarding a gate stay
#   completely untouched: they are there on purpose to defend the gate.
# - Every other station/object is instead "reparented" directly to the
#   enclosing sector (location class="sector") rather than to a sibling
#   zone: its absolute vanilla position (zone offset + local position)
#   becomes relative to the whole sector, so it benefits from the mod's
#   spread without any risk of landing in another zone (e.g. a highway
#   zone) that happened to be picked as the "nearest" one.

BEGIN {
    current_sector = ""
    current_connection = ""
    pending_x = ""
    pending_z = ""
    current_zone = ""
    in_gamestart = 0
    gamestart_ref = ""
    section = ""
    current_station = ""
    current_object = ""
    current_location_class = ""
    current_location_macro = ""
}

# --- zones.xml pass: protected zones (gates/SHCon). ---
FILENAME == zones_file {
    line = strip_comments($0)
    if (line == "") next
    if (line ~ /<macro name="[^"]*" class="zone">/) {
        match(line, /name="([^"]*)"/, arr)
        current_zone = tolower(arr[1])
        if (index(current_zone, "shcon") > 0) protected_zone[current_zone] = 1
    }
    if (line ~ /<connection / && current_zone != "") {
        if (index(line, "ref=\"gates\"") > 0) protected_zone[current_zone] = 1
    }
    if (line ~ /<\/macro>/ && current_zone != "") current_zone = ""
    next
}

# --- sectors.xml pass: natural radius per sector, and each zone's
#     position/ownership (for reparenting). ---
FILENAME == sectors_file {
    line = strip_comments($0)
    if (line == "") next
    if (line ~ /<macro name="[^"]*" class="sector">/) {
        match(line, /name="([^"]*)"/, arr)
        current_sector = tolower(arr[1])
    }
    if (current_sector != "" && line ~ /<connection /) {
        current_connection = ""
        pending_x = ""
        pending_z = ""
        if (match(line, /name="([^"]*)"/, conn_arr)) current_connection = conn_arr[1]
    }
    if (current_sector != "" && current_connection != "" && line ~ /<position x=/) {
        if (match(line, /x="([^"]*)"/, x_arr)) pending_x = x_arr[1]
        if (match(line, /z="([^"]*)"/, z_arr)) pending_z = z_arr[1]
        if (pending_x != "" && pending_z != "") {
            nr = sqrt((pending_x * pending_x) + (pending_z * pending_z))
            if (nr > sector_natural_radius[current_sector]) sector_natural_radius[current_sector] = nr
        }
    }
    if (current_sector != "" && current_connection != "" && line ~ /<macro ref="[^"]*" connection="sector"/) {
        if (match(line, /ref="([^"]*)"/, ref_arr)) {
            zone_name = tolower(ref_arr[1])
            zone_parent[zone_name] = current_sector
            zone_offset_x[zone_name] = pending_x + 0
            zone_offset_z[zone_name] = pending_z + 0
        }
    }
    next
}


# --- god.xml file: tracks the context (gamestart/station/object/location). ---
# (the FILENAME==zones_file / FILENAME==sectors_file blocks above all end
#  with "next", so this point is only reached for god.xml)
{
    line = strip_comments($0)
    if (line == "") next
}

line ~ /<gamestart ref="[^"]*"/ {
    in_gamestart = 1
    if (match(line, /ref="([^"]*)"/, arr)) gamestart_ref = arr[1]
}
line ~ /<\/gamestart>/ {
    in_gamestart = 0
    gamestart_ref = ""
    section = ""
    current_station = ""
    current_object = ""
}
line ~ /<stations>/ { section = "stations" }
line ~ /<\/stations>/ {
    if (section == "stations") { section = ""; current_station = ""; current_location_macro = "" }
}
line ~ /<objects>/ { section = "objects" }
line ~ /<\/objects>/ {
    if (section == "objects") { section = ""; current_object = ""; current_location_macro = "" }
}
line ~ /<station id="[^"]*"/ {
    if (match(line, /id="([^"]*)"/, arr)) current_station = arr[1]
    current_location_macro = ""
}
line ~ /<\/station>/ {
    current_station = ""
    current_location_class = ""
    current_location_macro = ""
}
line ~ /<object id="[^"]*"/ {
    if (match(line, /id="([^"]*)"/, arr)) current_object = arr[1]
    current_location_class = ""
    current_location_macro = ""
}
line ~ /<\/object>/ {
    current_object = ""
    current_location_class = ""
    current_location_macro = ""
}
line ~ /<location class="(zone|sector)"/ {
    if (match(line, /class="([^"]*)"/, c_arr)) current_location_class = c_arr[1]
    if (match(line, /macro="([^"]*)"/, l_arr)) current_location_macro = l_arr[1]
}

line ~ /<position x=/ {
    x = ""; y = ""; z = ""; yaw = ""; pitch = ""; roll = ""

    if (exclude != "" && current_location_macro != "" && match(current_location_macro, exclude)) next
    if (gamestart_ref != "" && tolower(gamestart_ref) ~ exclude_keywords) next
    if (current_station != "" && tolower(current_station) ~ exclude_keywords) next
    if (current_object != "" && tolower(current_object) ~ exclude_keywords) next
    if (current_location_macro != "" && tolower(current_location_macro) ~ exclude_keywords) next

    if (match(line, /x="([^"]*)"/, ax)) x = ax[1]
    if (match(line, /y="([^"]*)"/, ay)) y = ay[1]
    if (match(line, /z="([^"]*)"/, az)) z = az[1]
    if (x == "" || z == "") next
    if (x !~ /^[-+]?[0-9]*\.?[0-9]+$/) next
    if (z !~ /^[-+]?[0-9]*\.?[0-9]+$/) next

    if (match(line, /yaw="([^"]*)"/, aw)) yaw = aw[1]
    if (match(line, /pitch="([^"]*)"/, ap)) pitch = ap[1]
    if (match(line, /roll="([^"]*)"/, ar)) roll = ar[1]

    pos_sel = ""
    loc_sel = ""
    id_for_seed = ""
    if (current_station != "") {
        id_for_seed = "station:" current_station
        base_sel = (in_gamestart && gamestart_ref != "") \
            ? "/god/gamestart[@ref='" gamestart_ref "']/stations/station[@id='" current_station "']" \
            : "/god/stations/station[@id='" current_station "']"
        pos_sel = base_sel "/position"
        loc_sel = base_sel "/location"
    } else if (current_object != "") {
        id_for_seed = "object:" current_object
        base_sel = (in_gamestart && gamestart_ref != "") \
            ? "/god/gamestart[@ref='" gamestart_ref "']/objects/object[@id='" current_object "']" \
            : "/god/objects/object[@id='" current_object "']"
        pos_sel = base_sel "/position"
        loc_sel = base_sel "/location"
    }
    if (pos_sel == "") next

    location_key = tolower(current_location_macro)
    parent_sector = ""
    is_protected = 0

    if (current_location_class == "zone") {
        if (location_key in zone_parent) {
            parent_sector = zone_parent[location_key]
        }
        if (location_key in protected_zone) is_protected = 1
    }

    # Defense stations (id contains "defence"/"defense") guarding a gate:
    # leave them exactly where they are, untouched.
    id_lc = tolower((current_station != "") ? current_station : current_object)
    is_defence = (id_lc ~ /defen[cs]e/)
    if (is_protected && is_defence) next

    effective_factor = factor

    natural_radius = 0
    if (current_location_class == "sector" && location_key in sector_natural_radius) {
        natural_radius = sector_natural_radius[location_key]
    } else if (parent_sector != "" && parent_sector in sector_natural_radius) {
        natural_radius = sector_natural_radius[parent_sector]
    }
    effective_maxr = effective_max_radius(natural_radius, radius_floor, radius_headroom, radius_safety)

    reparented = 0
    new_location_macro = ""

    if (is_protected && parent_sector != "" && (location_key in zone_offset_x)) {
        # Reparent directly to the enclosing sector instead of a sibling
        # zone: a "nearest zone" guess could itself be a highway-only zone,
        # which would visually strand the station in the middle of a
        # highway. The sector itself has no such caveat.
        offset_x = zone_offset_x[location_key] + 0
        offset_z = zone_offset_z[location_key] + 0
        abs_x = (offset_x + x) * effective_factor
        abs_z = (offset_z + z) * effective_factor

        jitter_axis(abs_x, abs_z, id_for_seed "|reparent", effective_maxr, jitter_frac, jitter_minabs)
        abs_x = JITTER_X
        abs_z = JITTER_Z

        clamp_xz(abs_x, abs_z, 0, effective_maxr, clamp_margin)
        new_x = CLAMP_X
        new_z = CLAMP_Z

        reparented = 1
        new_location_macro = (parent_sector in sector_orig_case) ? sector_orig_case[parent_sector] : parent_sector
    }

    if (!reparented) {
        new_x = x * effective_factor
        new_z = z * effective_factor
        jitter_axis(new_x, new_z, id_for_seed, effective_maxr, jitter_frac, jitter_minabs)
        new_x = JITTER_X
        new_z = JITTER_Z
        clamp_xz(new_x, new_z, 0, effective_maxr, clamp_margin)
        new_x = CLAMP_X
        new_z = CLAMP_Z
    }

    y_out = (y == "") ? 0 : y

    extra_attrs = ""
    if (pitch != "") extra_attrs = extra_attrs " pitch=\"" pitch "\""
    if (roll != "") extra_attrs = extra_attrs " roll=\"" roll "\""
    if (yaw != "") extra_attrs = extra_attrs " yaw=\"" yaw "\""

    if (reparented) {
        printf("  <replace sel=\"%s\">\n    <location class=\"sector\" macro=\"%s\" />\n  </replace>\n", loc_sel, new_location_macro)
    }
    printf("  <replace sel=\"%s\">\n    <position x=\"%s\" y=\"%s\" z=\"%s\"%s />\n  </replace>\n", pos_sel, new_x, y_out, new_z, extra_attrs)
}

