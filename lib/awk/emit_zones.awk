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

    # Preserve the travel network unless explicitly disabled.
    if ((no_highways + 0) == 0) {
        if (index(current_macro, "SHCon") > 0) next
        if (index(current_conn_name, "Highway") > 0) next
        if (index(current_conn_ref, "Highway") > 0) next
        if (current_conn_ref == "gates") next
        if (index(current_conn_name, "Gate") > 0) next
        if (index(current_conn_ref, "gate") > 0) next
    }

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
    jitter_axis(new_x, new_z, seed, 0, jitter_frac, jitter_minabs)
    new_x = JITTER_X
    new_z = JITTER_Z

    clamp_xz(new_x, new_z, 0, maxr, clamp_margin)
    new_x = CLAMP_X
    new_z = CLAMP_Z

    if (current_conn_name != "") {
        sel = "/macros/macro[@name='" current_macro "']/connections/connection[@name='" current_conn_name "']/offset/position"
    } else if (current_conn_ref != "") {
        sel = "/macros/macro[@name='" current_macro "']/connections/connection[@ref='" current_conn_ref "']/offset/position"
    } else {
        next
    }

    printf("  <replace sel=\"%s\">\n    <position x=\"%s\" y=\"%s\" z=\"%s\" />\n  </replace>\n", sel, new_x, y, new_z)
}
