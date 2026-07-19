# common.awk - AWK helpers shared by all emit_*.awk scripts.
# Always loaded first via: awk -f common.awk -f emit_XXX.awk ...
BEGIN {
    # Avoid scientific notation (e.g. "1.04e+06"), unreadable/invalid in XML.
    CONVFMT = "%.6f"
    OFMT = "%.6f"
}
# Strips XML comments <!-- ... --> (including multi-line ones) from a line.
function strip_comments(raw,    out, start, rest, finish) {
    out = raw
    while (1) {
        if (in_comment) {
            finish = index(out, "-->")
            if (finish == 0) return ""
            out = substr(out, finish + 3)
            in_comment = 0
        }
        start = index(out, "<!--")
        if (start == 0) break
        rest = substr(out, start + 4)
        finish = index(rest, "-->")
        if (finish == 0) {
            out = substr(out, 1, start - 1)
            in_comment = 1
            break
        }
        out = substr(out, 1, start - 1) substr(rest, finish + 3)
    }
    return out
}
# True if the line (already lowercased by the caller) contains a resource
# keyword (asteroids, gas, ore...).
function is_resource_keyword(lower_line) {
    return (index(lower_line, "asteroid") > 0 || index(lower_line, "ore") > 0 || \
            index(lower_line, "silicon") > 0 || index(lower_line, "ice") > 0 || \
            index(lower_line, "gas") > 0 || index(lower_line, "hydrogen") > 0 || \
            index(lower_line, "helium") > 0 || index(lower_line, "methane") > 0 || \
            index(lower_line, "nividium") > 0 || index(lower_line, "nebula") > 0 || \
            index(lower_line, "fog") > 0 || index(lower_line, "debris") > 0 || \
            index(lower_line, "resource") > 0)
}
# Character -> code lookup table, built once, used by str_hash() for a
# deterministic hash without any external dependency.
function build_charset(    i) {
    if (charset_built) return
    charset = ""
    for (i = 1; i < 256; i++) charset = charset sprintf("%c", i)
    charset_built = 1
}
# Deterministic (djb2-like) hash of a string, used for pseudo-randomness.
function str_hash(s,    i, c, h) {
    build_charset()
    h = 5381
    for (i = 1; i <= length(s); i++) {
        c = index(charset, substr(s, i, 1))
        h = (h * 33 + c) % 2147483647
    }
    return h
}
# Deterministic pseudo-random value in [-1, 1) derived from a "seed".
# Same seed => same value on every generation (reproducible).
function pseudo_rand(seed,    h) {
    h = str_hash(seed)
    return ((h % 200000) - 100000) / 100000.0
}
# Clamps x/z to a max radius from the sector center. "phase" (radians) lets
# several points derived from the same position (extra resource zones) be
# spread tangentially. Result stored in globals CLAMP_X / CLAMP_Z /
# CLAMP_FLAG (1 if a clamp actually happened).
function clamp_xz(x, z, phase, maxr, margin,    r, theta, rr) {
    r = sqrt((x * x) + (z * z))
    if (r == 0) {
        CLAMP_X = 0
        CLAMP_Z = 0
        CLAMP_FLAG = 0
        return
    }
    theta = atan2(z, x) + phase
    rr = r
    CLAMP_FLAG = 0
    if (rr > maxr) {
        rr = maxr * margin
        CLAMP_FLAG = 1
    }
    CLAMP_X = rr * cos(theta)
    CLAMP_Z = rr * sin(theta)
}
# Effective clamp ceiling for a sector: never goes below the sector's own
# vanilla extent (with headroom), subject to an absolute safety ceiling
# against pathological outliers.
function effective_max_radius(natural, floor, headroom, safety,    eff, candidate) {
    eff = floor
    if (natural + 0 > 0) {
        candidate = natural * headroom
        if (candidate > eff) eff = candidate
    }
    if (eff > safety) eff = safety
    return eff
}
# If x or z is exactly 0 after scaling, applies a pseudo-random (but
# deterministic, via "seed") offset so objects don't pile up along the
# sector's axes. Result stored in JITTER_X / JITTER_Z.
function jitter_axis(x, z, seed, ref_radius, frac, minabs,    mag, base) {
    JITTER_X = x
    JITTER_Z = z
    base = sqrt((x * x) + (z * z))
    if (ref_radius > base) base = ref_radius
    mag = base * frac
    if (mag < minabs) mag = minabs
    if (x == 0) JITTER_X = pseudo_rand(seed "|x") * mag
    if (z == 0) JITTER_Z = pseudo_rand(seed "|z") * mag
}
