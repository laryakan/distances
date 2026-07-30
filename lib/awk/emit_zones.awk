# emit_zones.awk - Generates the <diff> body for a zones.xml file.
# Requires common.awk loaded first. Single pass over the zones.xml file.

BEGIN {
    current_macro = ""
    current_conn_name = ""
    current_conn_ref = ""
    if (no_highways == "") no_highways = 0
}

{
    line = strip_comments($0)
    if (line == "") next
}

line ~ /<macro name="[^"]*" class="zone">/ {
    match(line, /name="([^"]*)"/, arr)
    current_macro = arr[1]
}

line ~ /<connection / {
    current_conn_name = ""
    current_conn_ref = ""
    if (match(line, /name="([^"]*)"/, n_arr)) current_conn_name = n_arr[1]
    if (match(line, /ref="([^"]*)"/, r_arr)) current_conn_ref = r_arr[1]
}

line ~ /<position x=/ && current_macro != "" {
    # Excluded sectors (hazard/special mechanics): leave untouched.
    if (exclude != "" && match(current_macro, exclude)) next

    lower_macro = tolower(current_macro)
    lower_conn_name = tolower(current_conn_name)
    lower_conn_ref = tolower(current_conn_ref)

    is_travel_link = 0
    if (index(lower_macro, "shcon") > 0) is_travel_link = 1
    if (index(lower_conn_name, "shcon") > 0) is_travel_link = 1
    if (index(lower_conn_ref, "shcon") > 0) is_travel_link = 1
    if (index(lower_conn_name, "superhighway") > 0) is_travel_link = 1
    if (index(lower_conn_ref, "superhighway") > 0) is_travel_link = 1
    if (index(lower_conn_name, "highway") > 0) is_travel_link = 1
    if (index(lower_conn_ref, "highway") > 0) is_travel_link = 1
    if (index(lower_conn_name, "accelerator") > 0) is_travel_link = 1
    if (index(lower_conn_ref, "accelerator") > 0) is_travel_link = 1
    if (lower_conn_ref == "gates") is_travel_link = 1
    if (index(lower_conn_name, "gate") > 0) is_travel_link = 1
    if (index(lower_conn_ref, "gate") > 0) is_travel_link = 1

    # In default mode, preserve travel-critical links
    # (gates/accelerators/superhighways/SHCon).
    # With --no-highways, move them in scale-only mode.
    if ((no_highways + 0) == 0 && is_travel_link) next

    match(line, /x="([^"]*)"/, x_arr)
    match(line, /y="([^"]*)"/, y_arr)
    match(line, /z="([^"]*)"/, z_arr)
    x = x_arr[1]
    y = y_arr[1]
    z = z_arr[1]
    if (x == "" || y == "" || z == "") next

    new_x = x * factor
    new_z = z * factor

    seed = current_macro "|" (current_conn_name != "" ? current_conn_name : current_conn_ref)

    if ((no_highways + 0) != 0 && is_travel_link) {
        # Keep travel anchors aligned with superhighway scaling.
        # Scale-only path: no rotation, no jitter, no clamp.
    } else {
        # General spread path for regular content.
        rotate_angular(new_x, new_z, seed)
        new_x = ROTATED_X
        new_z = ROTATED_Z

        jitter_axis(new_x, new_z, seed, 0, jitter_frac, jitter_minabs)
        new_x = JITTER_X
        new_z = JITTER_Z

        clamp_xz(new_x, new_z, 0, maxr, clamp_margin)
        new_x = CLAMP_X
        new_z = CLAMP_Z
    }

    if (current_conn_name != "") {
        sel = "/macros/macro[@name='" current_macro "']/connections/connection[@name='" current_conn_name "']/offset/position"
    } else if (current_conn_ref != "") {
        sel = "/macros/macro[@name='" current_macro "']/connections/connection[@ref='" current_conn_ref "']/offset/position"
    } else {
        next
    }

    printf("  <replace sel=\"%s\">\n    <position x=\"%s\" y=\"%s\" z=\"%s\" />\n  </replace>\n", sel, new_x, y, new_z)
}
