"""
Compare private_roads() output ("_compare") against private_roads_fast() output
("_compare_fast") to verify the single-pass overlay produces identical results.

The two sets of tables can live in different geodatabases/SDE connections -
arcpy references tables by full path, so no linking between workspaces is
needed (see alter_final_tables.py for the same cross-workspace pattern).

Only rows where AREARATE_CODE is not null are compared: private_roads()'s
per-code Identity keeps every citywide parcel, so its "_compare" tables also
carry a large block of AREARATE_CODE IS NULL rows for parcels outside that one
code's boundary. private_roads_fast() splits its combined result with
TableSelect on AREARATE_CODE = '<code>', so its "_compare_fast" tables never
have null rows. That difference is expected, not a bug - it isn't part of the
comparison.
"""

import os
import arcpy

AREA_RATE_CODES = [f"R{str(i * 10).zfill(3)}" for i in range(22)]

AREA_TOLERANCE = 0.01  # SHAPE_area difference (in the layer's area units) to treat as a match


def load_compare_table(workspace, table_name):
    """Read a SAP_PrivRd_*_compare(_fast) table into {PID: (FREQUENCY, SHAPE_area)}."""

    table_path = os.path.join(workspace, table_name)

    rows = {}
    with arcpy.da.SearchCursor(table_path, ["PID", "AREARATE_CODE", "FREQUENCY", "SHAPE_area"]) as cursor:
        for pid, area_rate_code, frequency, shape_area in cursor:
            if area_rate_code is None:
                continue
            rows[pid] = (frequency, shape_area)

    return rows


def compare_area_rate_code(old_workspace, new_workspace, area_rate_code):
    """Compare one code's private_roads() output against private_roads_fast()'s."""

    old_rows = load_compare_table(old_workspace, f"SAP_PrivRd_{area_rate_code}_compare")
    new_rows = load_compare_table(new_workspace, f"SAP_PrivRd_{area_rate_code}_compare_fast")

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
        print(f"\tPIDs in _compare but missing from _compare_fast: {result['missing_in_fast']}")

    if result["missing_in_old"]:
        print(f"\tPIDs in _compare_fast but missing from _compare: {result['missing_in_old']}")

    if result["frequency_mismatches"]:
        print(f"\tFREQUENCY mismatches (PID, old, fast): {result['frequency_mismatches']}")

    if result["area_mismatches"]:
        print(f"\tSHAPE_area mismatches beyond tolerance (PID, old, fast): {result['area_mismatches']}")

    return has_problems


if __name__ == "__main__":

    # Point these at wherever the two runs' tables actually live - they don't
    # need to be in the same geodatabase or SDE connection.
    OLD_WORKSPACE = r"PATH_TO_COPIED_GEODATABASE_WITH_compare_TABLES"
    NEW_WORKSPACE = r"E:\HRM\Scripts\SDE\SQL\Prod\prod_RW_sdeadm.sde"

    any_mismatch = False

    for area_rate_code in AREA_RATE_CODES:
        result = compare_area_rate_code(OLD_WORKSPACE, NEW_WORKSPACE, area_rate_code)

        if print_report(result):
            any_mismatch = True

    print("\nAll codes matched." if not any_mismatch else "\nMismatches found - see above.")
