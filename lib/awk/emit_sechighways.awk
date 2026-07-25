# emit_sechighways.awk - Simple scaling for superhighway entry/exit points
# No jitter, clamping, or protection logic - just direct position scaling

BEGIN {
    current_macro = ""
    current_conn_ref = ""
    if (no_highways == "") no_highways = 0
}

{
    line = strip_comments($0)
    if (line == "") next
}

line ~ /<macro name="[^"]*" class="highway">/ {
    match(line, /name="([^"]*)"/, arr)
    current_macro = arr[1]
}

line ~ /<connection ref="(entrypoint|exitpoint)">/ {
    match(line, /ref="([^"]*)"/, r_arr)
    current_conn_ref = r_arr[1]
}

line ~ /<position x=/ && current_macro != "" && current_conn_ref != "" {
    match(line, /x="([^"]*)"/, x_arr)
    match(line, /y="([^"]*)"/, y_arr)
    match(line, /z="([^"]*)"/, z_arr)
    x = x_arr[1]
    y = y_arr[1]
    z = z_arr[1]
    if (x == "" || y == "" || z == "") next

    # Scale superhighway entry/exit positions.
    # In --no-highways mode: scale superhighways proportionally with zones/sectors
    # to maintain alignment with SHCon gate zones. Scale-only (no jitter/clamp).
    new_x = x * factor
    new_z = z * factor

    sel = "/macros/macro[@name='" current_macro "']/connections/connection[@ref='" current_conn_ref "']/offset/position"
    printf("  <replace sel=\"%s\">\n    <position x=\"%s\" y=\"%s\" z=\"%s\" />\n  </replace>\n", sel, new_x, y, new_z)

    current_conn_ref = ""
}
