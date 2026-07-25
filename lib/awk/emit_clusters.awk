# emit_clusters.awk - Generates the <diff> body for a clusters.xml file.
# Scales cluster-level offsets for sector and superhighway connections.
#
# This keeps absolute alignment between:
# - sector local offsets in sectors.xml
# - superhighway entry/exit offsets in sechighways.xml
# when a global scale factor is applied.

BEGIN {
    current_macro = ""
    current_conn_name = ""
    current_conn_ref = ""
}

{
    line = strip_comments($0)
    if (line == "") next
}

line ~ /<macro name="[^"]*" class="cluster">/ {
    match(line, /name="([^"]*)"/, arr)
    current_macro = arr[1]
}

line ~ /<connection / {
    current_conn_name = ""
    current_conn_ref = ""
    if (match(line, /name="([^"]*)"/, n_arr)) current_conn_name = n_arr[1]
    if (match(line, /ref="([^"]*)"/, r_arr)) current_conn_ref = r_arr[1]
}

line ~ /<position x=/ && current_macro != "" && current_conn_name != "" {
    # Only scale travel/topology-critical cluster offsets.
    if (current_conn_ref != "sectors" && current_conn_ref != "sechighways") next

    match(line, /x="([^"]*)"/, x_arr)
    match(line, /y="([^"]*)"/, y_arr)
    match(line, /z="([^"]*)"/, z_arr)
    x = x_arr[1]
    y = y_arr[1]
    z = z_arr[1]
    if (x == "" || y == "" || z == "") next

    new_x = x * factor
    new_z = z * factor

    sel = "/macros/macro[@name='" current_macro "']/connections/connection[@name='" current_conn_name "']/offset/position"
    printf("  <replace sel=\"%s\">\n    <position x=\"%s\" y=\"%s\" z=\"%s\" />\n  </replace>\n", sel, new_x, y, new_z)
}

