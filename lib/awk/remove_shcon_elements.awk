# remove_shcon_elements.awk - Consolidated SHCon removal for zones/sectors/clusters
#
# Handles three types of removals when --no-highways is set:
# 1. Zone macro removals (zones.xml)
# 2. Sector connection removals (sectors.xml)
# 3. SuperHighway connection removals (clusters.xml)
#
# Usage:
#   Zones:    awk -f common.awk -f remove_shcon_elements.awk -v mode="zones" zones.xml
#   Sectors:  awk -f common.awk -f remove_shcon_elements.awk -v mode="sectors" sectors.xml
#   Clusters: awk -f common.awk -f remove_shcon_elements.awk -v mode="clusters" clusters.xml

BEGIN {
    if (no_highways == "") no_highways = 0
    if (mode == "") {
        print "ERROR: mode must be set to 'zones', 'sectors', or 'clusters'" > "/dev/stderr"
        exit 1
    }

    # Initialize state variables
    in_sector_macro = 0
    sector_macro_name = ""
    in_superhighway_conn = 0
    superhighway_conn_name = ""
    has_shcon = 0
}

# ==================== ZONES MODE ====================
# Remove SHCon gate zone macros entirely
mode == "zones" && (no_highways + 0) != 0 && /<macro name="[^"]*SHCon[^"]*GateZone_macro"/ {
    match($0, /name="([^"]*)"/, arr)
    macro_name = arr[1]
    printf("  <remove sel=\"/macros/macro[@name='%s']\" />\n", macro_name)
    next
}

# ==================== SECTORS MODE ====================
# Track sector context for precise XPath
mode == "sectors" && /<macro name="[^"]*Sector[^"]*_macro" class="sector">/ {
    match($0, /name="([^"]*)"/, arr)
    in_sector_macro = 1
    sector_macro_name = arr[1]
    next
}

mode == "sectors" && /<\/macro>/ && in_sector_macro {
    in_sector_macro = 0
    sector_macro_name = ""
    next
}

# Remove SHCon connections from sectors (when --no-highways is set)
mode == "sectors" && (no_highways + 0) != 0 && in_sector_macro && /<connection[^>]*name="[^"]*SHCon[^"]*GateZone_connection"/ {
    match($0, /name="([^"]*)"/, conn_arr)
    conn_name = conn_arr[1]
    printf("  <remove sel=\"/macros/macro[@name='%s']/connections/connection[@name='%s']\" />\n", sector_macro_name, conn_name)
    next
}

# ==================== CLUSTERS MODE ====================
# Track SuperHighway connections for SHCon references
mode == "clusters" && (no_highways + 0) != 0 && /<connection[^>]*ref="sechighways"/ {
    in_superhighway_conn = 1
    # Extract connection name if present
    if (match($0, /name="([^"]*)"/, arr)) {
        superhighway_conn_name = arr[1]
    } else {
        superhighway_conn_name = ""
    }
    has_shcon = 0
    next
}

# Check if this SuperHighway connection references a SHCon gate zone
mode == "clusters" && in_superhighway_conn && /<macro[^>]*SHCon[^"]*GateZone_macro"/ {
    has_shcon = 1
    next
}

# End of connection block - emit remove if contains SHCon
mode == "clusters" && /<\/connection>/ && in_superhighway_conn {
    if (has_shcon && superhighway_conn_name != "") {
        # Use connection name as selector (names are globally unique in clusters.xml)
        printf("  <remove sel=\"/macros/macro/connections/connection[@name='%s']\" />\n", superhighway_conn_name)
    }
    in_superhighway_conn = 0
    superhighway_conn_name = ""
    has_shcon = 0
    next
}

# Default: skip line (all output is explicitly printed above)
{
    next
}

