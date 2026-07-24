# emit_sechighways.awk - Generates <remove> entries for superhighways.
# Requires common.awk loaded first.

BEGIN {
    if (no_highways == "") no_highways = 0
    split(excluded_clusters, excl_arr, ",")
    for (i in excl_arr) {
        if (excl_arr[i] != "") excluded_cluster[excl_arr[i] + 0] = 1
    }
}

{
    line = strip_comments($0)
    if (line == "") next
}

line ~ /<macro name="[^"]*" class="highway">/ {
    if ((no_highways + 0) == 0) next

    match(line, /name="([^"]*)"/, arr)
    macro_name = arr[1]
    cluster_id = -1
    macro_lc = tolower(macro_name)
    if (match(macro_lc, /cluster_0*([0-9]+)_macro$/, c_arr)) {
        cluster_id = c_arr[1] + 0
    }

    if (cluster_id in excluded_cluster) next

    sel = "/macros/macro[@name='" macro_name "']"
    printf("  <remove sel=\"%s\" />\n", sel)
}
