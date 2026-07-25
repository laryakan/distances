# 🔧 RESERVED/FUTURE CODE ANALYSIS

## Files Not Currently Used in Pipeline

### 1. `lib/awk/emit_clusters.awk` (1.6 KB)

**Status:** ⏳ RESERVED (Not used in current pipeline)

**Purpose:** Would generate `<diff>` patches for `clusters.xml` files

**Why Reserved?**
- Clusters.xml is currently used as **input** (reference data) for resource profiling
- NOT output as patches in the current pipeline
- Reserved for future enhancements (e.g., direct SHCon/superhighway modification)

**Current Pipeline:**
- `clusters.xml` → read as input → extract resource regions → populate `sector_resource_from_clusters[]`
- No output patches generated

**Potential Future Use:**
- Modify superhighway entry/exit connections in clusters.xml
- Better SHCon management at cluster level
- Would require careful testing to avoid breaking inter-file sync

**Status in Release:** ✅ OK - Not a problem, just reserved for future features

### 2. `lib/process.sh::process_clusters_file()` (9 lines)

**Status:** ⏳ RESERVED (Not used in current pipeline)

**Current Code:**
```bash
process_clusters_file() {
    local input_file="$1"
    local output_file="$2"

    {
        echo '<?xml version="1.0" encoding="utf-8"?>'
        echo '<!-- Distances Mod - (reserved) clusters patch -->'
        echo '<diff>'
        echo '</diff>'
    } > "$output_file"
}
```

**Why It Exists:**
- Function stub for future clusters.xml processing
- Currently generates **empty patches** (no-op)
- Placeholder for when `emit_clusters.awk` is used

**Why Not Called:**
- No need to generate clusters.xml patches in current design
- Resource profiling uses clusters.xml as input reference only

**Status in Release:** ✅ OK - Harmless placeholder, could be removed but doesn't hurt

---

## Summary: Reserved Code is Acceptable

| File | Lines | Status | Impact | Keep? |
|------|-------|--------|--------|-------|
| `emit_clusters.awk` | 46 | Reserved | None (input only) | ✅ Keep - no harm, good for docs |
| `process_clusters_file()` | 9 | Stub | None (returns empty) | ✅ Keep - clear intention for future |

**Total unused code:** ~166 lines out of ~1,600 lines = **~10% of AWK**  
**Impact on functionality:** None - code is never executed  
**Impact on clarity:** Positive - documents design evolution and future extensibility

---

## Recommendation

**Status: ✅ ACCEPTABLE FOR RELEASE**

The reserved code serves as:
1. **Documentation** of previous design iterations
2. **Placeholder** for future enhancements
3. **Reference** for alternative approaches (e.g., complete SHCon removal)

**No cleanup needed** - it's clear from comments that this is reserved code, and it doesn't interfere with the current pipeline.

### Optional Future Enhancement
If you want to add clusters.xml modification support, you would:
1. Uncomment `emit_clusters.awk` logic
2. Call `process_clusters_file()` from `generate.sh`
3. Implement SuperHighway scaling/modification logic
4. Test thoroughly for 3-way sync integrity

**For v1.0.0 release:** Leave as-is. Good documentation of design.

