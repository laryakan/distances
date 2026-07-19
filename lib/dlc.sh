#!/bin/bash
# Distances Mod - DLC map filename resolution.

# Some DLCs use a file prefix different from their folder name.
get_dlc_map_prefix() {
    local dlc_name="$1"

    case "$dlc_name" in
        ego_dlc_split) echo "dlc4" ;;
        ego_dlc_timelines) echo "dlc7" ;;
        *) echo "${dlc_name#ego_}" ;;
    esac
}

