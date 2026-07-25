# emit_sectors.awk - Generates the <diff> body for a sectors.xml file.
# Requires common.awk loaded first (-f common.awk -f emit_sectors.awk).
#
# Expected invocation (see lib/process.sh):
#   awk -f common.awk -f emit_sectors.awk -v factor=... -v zones_file=F -v sectors_file=S \
#       [F] S S
# i.e.: zones.xml (optional, one pass), then sectors.xml twice (1st pass:
# natural radius, 2nd pass: emission).

BEGIN {
    current_zone = ""
    current_macro = ""
    current_connection = ""
    current_connection_ref = ""
    current_zone_ref = ""
    sectors_pass = 0
    if (no_highways == "") no_highways = 0
}

# --- zones.xml pass: protected zones (gates/SHCon), "resource" zones,
#     and the list of all valid zones (as opposed to highway macros). ---
FILENAME == zones_file {
    line = strip_comments($0)
    if (line == "") next

    if (line ~ /<macro name="[^"]*" class="zone">/) {
        match(line, /name="([^"]*)"/, arr)
        current_zone = arr[1]
        zone_map[current_zone] = 1
        is_resource_zone = 0
        if ((no_highways + 0) == 0 && index(current_zone, "SHCon") > 0) {
            protected_map[current_zone] = 1
        }
    }
    if (current_zone != "" && line ~ /<connection /) {
        lower_line = tolower(line)
        is_travel_conn = 0
        if (index(lower_line, "ref=\"gates\"") > 0) is_travel_conn = 1
        if (index(lower_line, "highway") > 0) is_travel_conn = 1
        if (index(lower_line, "_gate\"") > 0) is_travel_conn = 1
        if (index(lower_line, "clustergate") > 0) is_travel_conn = 1
        if (is_travel_conn) travel_zone_map[current_zone] = 1
        if ((no_highways + 0) == 0 && is_travel_conn) protected_map[current_zone] = 1
        if (!is_travel_conn) is_resource_zone = 1
        if (is_resource_keyword(lower_line)) is_resource_zone = 1
    }
    if (current_zone != "" && line ~ /<macro ref="[^"]*"/) {
        if (is_resource_keyword(tolower(line))) is_resource_zone = 1
    }
    if (current_zone != "" && line ~ /<\/macro>/) {
        if (is_resource_zone) resource_map[current_zone] = 1
        current_zone = ""
    }
    next
}

# --- sectors.xml pass 1: natural radius (largest vanilla offset) per
#     sector, used to compute the clamp ceiling. ---
FILENAME == sectors_file && FNR == 1 {
    sectors_pass++
    sector_macro = ""
}

FILENAME == sectors_file && sectors_pass == 1 {
    line = strip_comments($0)
    if (line == "") next
    if (line ~ /<macro name="[^"]*" class="sector">/) {
        match(line, /name="([^"]*)"/, s_arr)
        sector_macro = s_arr[1]
    }
    if (sector_macro != "" && line ~ /<position x=/) {
        match(line, /x="([^"]*)"/, nx_arr)
        match(line, /z="([^"]*)"/, nz_arr)
        if (nx_arr[1] != "" && nz_arr[1] != "") {
            nr = sqrt((nx_arr[1] * nx_arr[1]) + (nz_arr[1] * nz_arr[1]))
            if (nr > sector_natural_radius[sector_macro]) sector_natural_radius[sector_macro] = nr
        }
    }
    next
}

# --- sectors.xml pass 2: emit the <replace>/<add> diff entries. ---
FILENAME == sectors_file && sectors_pass == 2 {
    line = strip_comments($0)
    if (line == "") next

    if (line ~ /<macro name="[^"]*" class="sector">/) {
        match(line, /name="([^"]*)"/, arr)
        current_macro = arr[1]
    }
    if (line ~ /<connection name="([^"]*)"/) {
        match(line, /name="([^"]*)"/, arr)
        current_connection = arr[1]
        current_connection_ref = ""
        if (match(line, /ref="([^"]*)"/, ref_conn_arr)) current_connection_ref = ref_conn_arr[1]
        current_zone_ref = ""
        pending_x = ""
        pending_y = ""
        pending_z = ""
    }
    if (line ~ /<position x=/ && current_macro != "" && current_connection != "") {
        match(line, /x="([^"]*)"/, x_arr)
        match(line, /y="([^"]*)"/, y_arr)
        match(line, /z="([^"]*)"/, z_arr)
        pending_x = x_arr[1]
        pending_y = y_arr[1]
        pending_z = z_arr[1]
    }
    if (line ~ /<macro ref="[^"]*" connection="sector"/ && current_macro != "" && current_connection != "") {
        match(line, /ref="([^"]*)"/, ref_arr)
        current_zone_ref = ref_arr[1]

         # Excluded sector (hazard/special mechanic): leave it untouched.
         if (exclude != "" && match(current_macro, exclude)) next
         is_highway_conn = 0
         if (current_connection_ref == "zonehighways") is_highway_conn = 1
         if (index(current_connection, "Highway") > 0) is_highway_conn = 1
         if (index(current_zone_ref, "Highway") > 0) is_highway_conn = 1

         # In --no-highways mode, remove regular highways but allow SHCon to scale.
         is_shcon_link = 0
         if (index(current_connection, "SHCon") > 0) is_shcon_link = 1
         if (index(current_zone_ref, "SHCon") > 0) is_shcon_link = 1

         if ((no_highways + 0) != 0 && is_highway_conn && !is_shcon_link) {
             sel_remove = "/macros/macro[@name='" current_macro "']/connections/connection[@name='" current_connection "']"
             printf("  <remove sel=\"%s\" />\n", sel_remove)
             next
         }
         # In default mode, preserve all travel-critical links.
         if ((no_highways + 0) == 0) {
             if (index(current_connection, "SHCon") > 0) next
             if (index(current_connection, "Highway") > 0) next
         }

        # Travel-critical links (gates/SHCon) must stay numerically aligned with
        # superhighway entry/exit scaling. In --no-highways, move them by scale
        # only (no angular rotation, no jitter, no clamp).
        is_gate_link = 0
        is_shcon_link = 0
        if (index(current_connection, "SHCon") > 0) is_gate_link = 1
        if (index(current_zone_ref, "SHCon") > 0) is_gate_link = 1
        if (index(current_connection, "SHCon") > 0) is_shcon_link = 1
        if (index(current_zone_ref, "SHCon") > 0) is_shcon_link = 1
        if (current_connection_ref == "gates") is_gate_link = 1
        if (index(current_connection, "Gate") > 0) is_gate_link = 1
         if (index(current_zone_ref, "Gate") > 0) is_gate_link = 1
         if (current_zone_ref in travel_zone_map) is_gate_link = 1

         if (!(current_zone_ref in zone_map)) next
        if (current_zone_ref in protected_map) next
        if (pending_x == "" || pending_y == "" || pending_z == "") next

        is_resource = (current_zone_ref in resource_map) ? 1 : 0
        natural_radius = (current_macro in sector_natural_radius) ? sector_natural_radius[current_macro] : 0

        effective_factor = factor
        effective_maxr = effective_max_radius(natural_radius, radius_floor, radius_headroom, radius_safety)

        new_x = pending_x * effective_factor
        new_z = pending_z * effective_factor

        seed = current_macro "|" current_connection

        if ((no_highways + 0) != 0 && is_gate_link) {
            # Scale-only path for gate/SHCon travel anchors.
            new_x = pending_x * effective_factor
            new_z = pending_z * effective_factor
        } else {
            # General spread path for regular content.
            rotate_angular(new_x, new_z, seed)
            new_x = ROTATED_X
            new_z = ROTATED_Z

            jitter_axis(new_x, new_z, seed, effective_maxr, jitter_frac, jitter_minabs)
            new_x = JITTER_X
            new_z = JITTER_Z

            clamp_xz(new_x, new_z, 0, effective_maxr, clamp_margin)
            new_x = CLAMP_X
            new_z = CLAMP_Z
        }

        sel = "/macros/macro[@name='" current_macro "']/connections/connection[@name='" current_connection "']/offset/position"
        printf("  <replace sel=\"%s\">\n    <position x=\"%s\" y=\"%s\" z=\"%s\" />\n  </replace>\n", sel, new_x, pending_y, new_z)

         # Extra logistics zones, further out, to spread traffic.
         extra_x = new_x * extra_mult_a
         extra_z = new_z * extra_mult_a
         extra_x2 = new_x * extra_mult_b
         extra_z2 = new_z * extra_mult_b
         extra_x3 = new_x * extra_mult_c
         extra_z3 = new_z * extra_mult_c
         extra_x4 = new_x * extra_mult_d
         extra_z4 = new_z * extra_mult_d

          clamp_xz(extra_x, extra_z, phase_a, effective_maxr, 1.0)
          extra_x = CLAMP_X
          extra_z = CLAMP_Z
          clamp_xz(extra_x2, extra_z2, phase_b, effective_maxr, 1.0)
          extra_x2 = CLAMP_X
          extra_z2 = CLAMP_Z
          clamp_xz(extra_x3, extra_z3, phase_c, effective_maxr, 1.0)
          extra_x3 = CLAMP_X
          extra_z3 = CLAMP_Z
          clamp_xz(extra_x4, extra_z4, phase_d, effective_maxr, 1.0)
          extra_x4 = CLAMP_X
          extra_z4 = CLAMP_Z

         add_sel = "/macros/macro[@name='" current_macro "']/connections"
         extra_conn = current_connection "_resourceextra_a"
         printf("  <add sel=\"%s\">\n", add_sel)
         printf("    <connection name=\"%s\" ref=\"zones\">\n", extra_conn)
         printf("      <offset>\n        <position x=\"%s\" y=\"%s\" z=\"%s\" />\n      </offset>\n", extra_x, pending_y, extra_z)
         printf("      <macro ref=\"%s\" connection=\"sector\" />\n", current_zone_ref)
         printf("    </connection>\n  </add>\n")

         # Extra zone for all sectors (not just resource zones)
         extra_conn3 = current_connection "_resourceextra_c"
         printf("  <add sel=\"%s\">\n", add_sel)
         printf("    <connection name=\"%s\" ref=\"zones\">\n", extra_conn3)
         printf("      <offset>\n        <position x=\"%s\" y=\"%s\" z=\"%s\" />\n      </offset>\n", extra_x3, pending_y, extra_z3)
         printf("      <macro ref=\"%s\" connection=\"sector\" />\n", current_zone_ref)
         printf("    </connection>\n  </add>\n")

         if (is_resource) {
             extra_conn2 = current_connection "_resourceextra_b"
             printf("  <add sel=\"%s\">\n", add_sel)
             printf("    <connection name=\"%s\" ref=\"zones\">\n", extra_conn2)
             printf("      <offset>\n        <position x=\"%s\" y=\"%s\" z=\"%s\" />\n      </offset>\n", extra_x2, pending_y, extra_z2)
             printf("      <macro ref=\"%s\" connection=\"sector\" />\n", current_zone_ref)
             printf("    </connection>\n  </add>\n")

             # Extra zone d for resource zones
             extra_conn4 = current_connection "_resourceextra_d"
             printf("  <add sel=\"%s\">\n", add_sel)
             printf("    <connection name=\"%s\" ref=\"zones\">\n", extra_conn4)
             printf("      <offset>\n        <position x=\"%s\" y=\"%s\" z=\"%s\" />\n      </offset>\n", extra_x4, pending_y, extra_z4)
             printf("      <macro ref=\"%s\" connection=\"sector\" />\n", current_zone_ref)
             printf("    </connection>\n  </add>\n")
         }
    }
}
