"""
Compare private_roads()'s per-code output against private_roads_fast()'s combined
output to verify the single-pass overlay produces identical results.

private_roads() writes its final SAP_PrivRd_{code}_compare tables straight to
sde_workspace, not to the local scratch geodatabase - so a local copy of that
scratch gdb (e.g. scratch_1.gdb) only has the raw, per-code Local_{code}_Identity
feature classes: one row per parcel/boundary overlay slice, not yet grouped by
PID. This script aggregates those rows itself (group by PID, sum SHAPE_area,
count rows) to reproduce what Frequency_analysis would have produced.

private_roads_fast() writes its combined Frequency result to PrivRd_fast_Frequency
in the local scratch geodatabase before splitting it into per-code SDE tables, so
the "new" side is already aggregated - just filter that one table by AREARATE_CODE.

The two geodatabases don't need to be related in any way - arcpy references
tables by full path (see alter_final_tables.py for the same cross-workspace
pattern), so comparing a table in one .gdb against a table in another is
completely normal.

Only rows where AREARATE_CODE matches the code being compared are included:
private_roads()'s per-code Identity keeps every citywide parcel, tagging
everything outside that one code's boundary with a null AREARATE_CODE. Those
null rows aren't part of a meaningful comparison, so they're filtered out here.
"""

import os
import arcpy

AREA_RATE_CODES = [f"R{str(i * 10).zfill(3)}" for i in range(22)]

AREA_TOLERANCE = 0.01  # SHAPE_area difference (in the layer's area units) to treat as a match


def load_old_identity_rows(workspace, area_rate_code):
    """
    Aggregate private_roads()'s raw Local_{code}_Identity feature class into
    {PID: (count, summed_shape_area)}, reproducing what Frequency_analysis
    would have produced from it.
    """

    table_path = os.path.join(workspace, f"Local_{area_rate_code}_Identity")
    where_clause = f"AREARATE_CODE = '{area_rate_code}'"

    rows = {}
    with arcpy.da.SearchCursor(table_path, ["PID", "SHAPE_area"], where_clause) as cursor:
        for pid, shape_area in cursor:
            count, total_area = rows.get(pid, (0, 0.0))
            rows[pid] = (count + 1, total_area + (shape_area or 0.0))

    return rows


def load_fast_frequency_rows(workspace, area_rate_code):
    """Read private_roads_fast()'s already-aggregated PrivRd_fast_Frequency table."""

    table_path = os.path.join(workspace, "PrivRd_fast_Frequency")
    where_clause = f"AREARATE_CODE = '{area_rate_code}'"

    rows = {}
    with arcpy.da.SearchCursor(table_path, ["PID", "FREQUENCY", "SHAPE_area"], where_clause) as cursor:
        for pid, frequency, shape_area in cursor:
            rows[pid] = (frequency, shape_area)

    return rows


def compare_area_rate_code(old_workspace, new_workspace, area_rate_code):
    """Compare one code's private_roads() output against private_roads_fast()'s."""

    old_rows = load_old_identity_rows(old_workspace, area_rate_code)
    new_rows = load_fast_frequency_rows(new_workspace, area_rate_code)

    old_pids = set(old_rows)
    new_pids = set(new_rows)

    frequency_mismatches = []
    area_mismatches = []

    for pid in old_pids & new_pids:
        old_frequency, old_area = old_rows[pid]
        new_frequency, new_area = new_rows[pid]

        if old_frequency != new_frequency:
            frequency_mismatches.append((pid, old_frequency, new_frequency))

        if abs(old_area - new_area) > AREA_TOLERANCE:
            area_mismatches.append((pid, old_area, new_area))

    return {
        "area_rate_code": area_rate_code,
        "old_pid_count": len(old_pids),
        "new_pid_count": len(new_pids),
        "missing_in_fast": sorted(old_pids - new_pids),
        "missing_in_old": sorted(new_pids - old_pids),
        "frequency_mismatches": frequency_mismatches,
        "area_mismatches": area_mismatches,
    }


def print_report(result):
    has_problems = any([
        result["missing_in_fast"],
        result["missing_in_old"],
        result["frequency_mismatches"],
        result["area_mismatches"],
    ])

    status = "MISMATCH" if has_problems else "match"
    code = result["area_rate_code"]
    print(f"{code}: {status} (old={result['old_pid_count']} PIDs, fast={result['new_pid_count']} PIDs)")

    if result["missing_in_fast"]:
        print(f"\tPIDs in old Identity but missing from fast Frequency: {result['missing_in_fast']}")

    if result["missing_in_old"]:
        print(f"\tPIDs in fast Frequency but missing from old Identity: {result['missing_in_old']}")

    if result["frequency_mismatches"]:
        print(f"\tFREQUENCY mismatches (PID, old, fast): {result['frequency_mismatches']}")

    if result["area_mismatches"]:
        print(f"\tSHAPE_area mismatches beyond tolerance (PID, old, fast): {result['area_mismatches']}")

    return has_problems


if __name__ == "__main__":

    # scratch_1.gdb - local workspace copied from the private_roads() run,
    # holding the raw per-code Local_{code}_Identity feature classes.
    OLD_WORKSPACE = r"PATH_TO_scratch_1.gdb"

    # scratch.gdb - local workspace from the private_roads_fast() run, holding
    # the combined, already-aggregated PrivRd_fast_Frequency table.
    NEW_WORKSPACE = r"PATH_TO_scratch.gdb"

    any_mismatch = False

    for area_rate_code in AREA_RATE_CODES:
        result = compare_area_rate_code(OLD_WORKSPACE, NEW_WORKSPACE, area_rate_code)

        if print_report(result):
            any_mismatch = True

    print("\nAll codes matched." if not any_mismatch else "\nMismatches found - see above.")
