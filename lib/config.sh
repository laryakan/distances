#!/bin/bash
# Distances Mod - Shared configuration and tuning constants.

# Hazard sectors (damage/tide mechanics) excluded from any modification.
EXCLUDE_SECTORS=(
    "[Cc]luster_27_[Ss]ector001_macro"  # The Void
    "[Cc]luster_605_[Ss]ector001_macro" # Sanctuary of Darkness
    "[Cc]luster_500_[Ss]ector001_macro" # Avarice
    "[Cc]luster_500_[Ss]ector002_macro" # Avarice
    "[Cc]luster_500_[Ss]ector003_macro" # Avarice
    "[Cc]luster_113_[Ss]ector001_macro" # Overlaps with the Terran DLC
    "[Cc]luster_104_[Ss]ector001_macro" # Terran Torus radiation belt (hazard)
)

# Excludes story/tutorial/scenario-only content from god.xml (not open world).
EXCLUDE_NON_OPEN_WORLD_REGEX='story|tutorial|scenario|gamestart'

EXTRA_RESOURCE_ZONE_MULT=1.35
EXTRA_RESOURCE_ZONE_MULT_2=1.7
EXTRA_RESOURCE_ZONE_MULT_3=2.0
EXTRA_RESOURCE_ZONE_MULT_4=2.3
# Number of existing zone connections per sector used as anchors for extras.
# "ANCHORS" = how many base connections are selected in that sector.
# - with resources: spread extras from more anchors
# - without resources: keep it lighter (usually 1-2 anchors)
EXTRA_RESOURCE_ANCHORS_WITH_RESOURCE=1
EXTRA_RESOURCE_ANCHORS_NO_RESOURCE=1
# Number of extra zone copies emitted for each selected anchor connection.
# "COUNT" = how many variants (_resourceextra_a/b/c/d) are generated per anchor.
EXTRA_RESOURCE_COUNT_WITH_RESOURCE=1
EXTRA_RESOURCE_COUNT_NO_RESOURCE=2
MAX_SECTOR_RADIUS=250000
CLAMP_MARGIN=0.98
EXTRA_PHASE_A=0.04
EXTRA_PHASE_B=-0.04
EXTRA_PHASE_C=2.07
EXTRA_PHASE_D=2.11


# Some vanilla/DLC sectors already exceed MAX_SECTOR_RADIUS (e.g. Hatikvah's
# Choice I has a vanilla zone at ~237000 and a gate at ~261000). Clamping to a
# flat radius would flatten the whole sector onto a single circle. The
# effective per-sector ceiling therefore never goes below the sector's own
# vanilla extent (with headroom), while keeping an absolute safety ceiling
# against pathological outliers.
NATURAL_RADIUS_HEADROOM=1.15
SAFETY_MAX_RADIUS=1500000

# Pseudo-random (but deterministic) offset applied to an X/Z axis when it
# lands exactly on 0 after scaling, to avoid objects piling up along the
# sector's axes.
JITTER_FRACTION=0.08
JITTER_MIN_ABS=3000

build_exclude_pattern() {
    local pattern=""
    local sector
    for sector in "${EXCLUDE_SECTORS[@]}"; do
        if [[ -z "$pattern" ]]; then
            pattern="$sector"
        else
            pattern="${pattern}|${sector}"
        fi
    done
    echo "$pattern"
}

