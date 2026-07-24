# emit_highway_cleanup.awk
#
# Generates <remove> patches for SuperHighway connections inside clusters.xml
#
# Requires common.awk
#
# Variables:
#   no_highways=1
#   excluded_clusters="1,7,15"

BEGIN {
    if (no_highways == "")
        no_highways = 0

    split(excluded_clusters, excl_arr, ",")

    for (i in excl_arr) {
        if (excl_arr[i] != "")
            excluded_cluster[excl_arr[i] + 0] = 1
    }

    current_cluster = ""
    current_cluster_id = -1
}

{
    line = strip_comments($0)
    if (line == "")
        next
}

#
# Detect current cluster
#
line ~ /<macro name="Cluster_[0-9]+_macro" class="cluster">/ {

    match(line, /name="Cluster_([0-9]+)_macro"/, arr)

    current_cluster = arr[1]

    current_cluster_id = current_cluster + 0

    next
}

#
# Remove every SuperHighway connection
#
line ~ /<connection name="SuperHighway[0-9]+_Cluster_[0-9]+_connection"/ {

    if ((no_highways + 0) == 0)
        next

    if (current_cluster_id in excluded_cluster)
        next

    match(line, /name="([^"]*)"/, arr)

    connection_name = arr[1]

    printf("  <remove sel=\"/macros/macro[@name='Cluster_%02d_macro']/connections/connection[@name='%s']\" />\n",
           current_cluster_id,
           connection_name)
}