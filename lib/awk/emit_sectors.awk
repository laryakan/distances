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
    if (extra_anchors_with_resource == "" && extra_links_with_resource != "") extra_anchors_with_resource = extra_links_with_resource
    if (extra_anchors_without_resource == "" && extra_links_without_resource != "") extra_anchors_without_resource = extra_links_without_resource
    if (extra_anchors_with_resource == "") extra_anchors_with_resource = 2
    if (extra_anchors_without_resource == "") extra_anchors_without_resource = 1
    if (extra_count_with_resource == "") extra_count_with_resource = 4
    if (extra_count_without_resource == "") extra_count_without_resource = 2
}

function sector_macro_from_region_connection(conn_name,    arr, cluster_id, sector_id) {
    if (!match(conn_name, /^C([0-9]+)S([0-9]+)_Region[0-9]+_connection$/, arr)) return ""
    cluster_id = arr[1]
    sector_id = arr[2] + 0
    return "Cluster_" cluster_id "_Sector" sprintf("%03d", sector_id) "_macro"
}

function sector_macro_from_region_connection_dlc(conn_name,    arr, cluster_id, sector_id) {
    if (!match(conn_name, /^Cluster_?([0-9]+)_Sector([0-9]+)_Region[0-9]+_connection$/, arr)) return ""
    cluster_id = arr[1]
    sector_id = arr[2] + 0
    return "Cluster_" cluster_id "_Sector" sprintf("%03d", sector_id) "_macro"
}

function emit_extra_connection(add_sel, conn_name, zone_ref, yv, xv, zv) {
    printf("  <add sel=\"%s\">\n", add_sel)
    printf("    <connection name=\"%s\" ref=\"zones\">\n", conn_name)
    printf("      <offset>\n        <position x=\"%s\" y=\"%s\" z=\"%s\" />\n      </offset>\n", xv, yv, zv)
    printf("      <macro ref=\"%s\" connection=\"sector\" />\n", zone_ref)
    printf("    </connection>\n  </add>\n")
}

# --- clusters.xml pass (optional): mark sectors that contain collectable
#     resource regions. This is the most reliable source of sector resource
#     presence in vanilla.
FILENAME == clusters_file {
    line = strip_comments($0)
    if (line == "") next

    if (line ~ /<connection name="C[0-9]+S[0-9]+_Region[0-9]+_connection" ref="regions">/) {
        match(line, /name="([^"]+)"/, c_arr)
        current_cluster_sector_macro = sector_macro_from_region_connection(c_arr[1])
        in_cluster_region_connection = 1
    } else if (line ~ /<connection name="Cluster_?[0-9]+_Sector[0-9]+_Region[0-9]+_connection" ref="regions">/) {
        match(line, /name="([^"]+)"/, c_arr)
        current_cluster_sector_macro = sector_macro_from_region_connection_dlc(c_arr[1])
        in_cluster_region_connection = 1
    }

    if (in_cluster_region_connection && line ~ /<region ref="[^"]*"/) {
        match(line, /ref="([^"]*)"/, region_arr)
        if (current_cluster_sector_macro != "" && is_collectable_resource_region(region_arr[1])) {
            sector_resource_from_clusters[current_cluster_sector_macro] = 1
        }
    }

    if (in_cluster_region_connection && line ~ /<\/connection>/) {
        in_cluster_region_connection = 0
        current_cluster_sector_macro = ""
    }
    next
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
        if (index(lower_line, "accelerator") > 0) is_travel_conn = 1
        if (index(lower_line, "highway") > 0) is_travel_conn = 1
        if (index(lower_line, "_gate\"") > 0) is_travel_conn = 1
        if (index(lower_line, "clustergate") > 0) is_travel_conn = 1
        if (is_travel_conn) travel_zone_map[current_zone] = 1
        if ((no_highways + 0) == 0 && is_travel_conn) protected_map[current_zone] = 1
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
    if (sector_macro != "" && line ~ /<macro ref="[^"]*" connection="sector"/) {
        match(line, /ref="([^"]*)"/, zref_arr)
        if (zref_arr[1] in resource_map) sector_resource_from_zones[sector_macro] = 1
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
        if ((no_highways + 0) != 0 && is_highway_conn) {
            sel_remove = "/macros/macro[@name='" current_macro "']/connections/connection[@name='" current_connection "']"
            printf("  <remove sel=\"%s\" />\n", sel_remove)
            next
        }
        # In default mode, preserve travel-critical links.
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

        if ((no_highways + 0) != 0 && is_shcon_link) next

        if (!(current_zone_ref in zone_map)) next
        if (current_zone_ref in protected_map) next
        if (pending_x == "" || pending_y == "" || pending_z == "") next

        is_resource = (current_zone_ref in resource_map) ? 1 : 0
        sector_has_resource = ((current_macro in sector_resource_from_zones) || (current_macro in sector_resource_from_clusters)) ? 1 : 0
        sector_has_zone_resource = (current_macro in sector_resource_from_zones) ? 1 : 0
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

         # Extra logistics zones are controlled per-sector:
         # - sectors with resources: denser extras
         # - sectors without resources: 1-2 extras to make outskirts useful
         emit_anchor = 0
         if (sector_has_resource) {
             if (sector_has_zone_resource) {
                 if (is_resource) emit_anchor = 1
             } else {
                 emit_anchor = 1
             }
             anchor_limit = extra_anchors_with_resource + 0
             extra_count = extra_count_with_resource + 0
         } else {
             emit_anchor = 1
             anchor_limit = extra_anchors_without_resource + 0
             extra_count = extra_count_without_resource + 0
         }

         if (emit_anchor && sector_extra_anchor_count[current_macro] < anchor_limit && extra_count > 0) {
             sector_extra_anchor_count[current_macro]++

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
             if (extra_count >= 1) emit_extra_connection(add_sel, extra_conn, current_zone_ref, pending_y, extra_x, extra_z)

             extra_conn2 = current_connection "_resourceextra_b"
             if (extra_count >= 2) emit_extra_connection(add_sel, extra_conn2, current_zone_ref, pending_y, extra_x2, extra_z2)

             extra_conn3 = current_connection "_resourceextra_c"
             if (extra_count >= 3) emit_extra_connection(add_sel, extra_conn3, current_zone_ref, pending_y, extra_x3, extra_z3)

             extra_conn4 = current_connection "_resourceextra_d"
             if (extra_count >= 4) emit_extra_connection(add_sel, extra_conn4, current_zone_ref, pending_y, extra_x4, extra_z4)
         }
    }
}
