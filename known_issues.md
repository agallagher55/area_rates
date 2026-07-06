# Known Issues

## 1. Missing AANs Due to Provincial Data Timing Gap

The area rate process relies on two datasets from the Province of Nova Scotia: the parcel fabric (property boundaries) and a few LINNS tables (including one which link PIDs to AANs). When properties are reconsolidated or subdivided, the updates to these datasets likely happen at different times — the LINNS tables are updated before the parcel boundaries.

This creates a timing gap. For example, PID 40194946 (AAN 05626617):

- In **December**, this PID had a valid AAN and existed in the parcel fabric, so it appeared in last year's report.
- By **January**, the LINNS table had already been updated — the old PID was disconnected from its AAN (`TAXCONFIRM` set to `F`) in preparation for a new PID (41556374). However, the parcel fabric still contained the old boundaries and did not yet include the new PID's geometry.

As a result, during this year's processing, the spatial query finds the old parcel but the PID-to-AAN join returns no match, so the AAN drops out of the report. The new PID that will carry this AAN forward doesn't have a parcel boundary yet, so it can't be picked up spatially either.

This is a transient issue — once the Province updates the parcel fabric to reflect the new boundaries, these AANs will reappear in subsequent reports under their new PIDs. Alternatively, we could take a snapshot of the LINNS tables and then wait a couple months before using the parcel fabric. In summary, this is a consequence of the two provincial datasets being out of sync during property reconsolidations.

**Note:** this is unrelated to the parcel snapshot described in Issue #3 below, and that snapshot doesn't fix it — if anything, it removes the self-healing described above. Before the snapshot existed, `boundary_parcels()` read the live parcel fabric on every run, so a later run in the same season would automatically pick up the Province's fabric update once it landed. Now that the parcel fabric is frozen for the season, a later run keeps reusing whatever was live at export time, even after the Province catches the fabric up — the fix only takes effect once someone clears `export_path` and a fresh snapshot is exported (currently framed as a new-season action, not a mid-season one).

### Visuals

- The current parcel fabric, updated in February, for the parcels of interest, are in dotted black lines.
- The parcel fabric, as it looked in January, is in red.
- The LINNS PID-AAN lookup table from December is on the left and from January is on the right.

<img width="1437" height="689" alt="image" src="https://github.com/user-attachments/assets/5f26381e-d1c1-47d1-be4b-e2857fd33065" />
<img width="745" height="547" alt="image" src="https://github.com/user-attachments/assets/dd102898-4530-4c2f-9801-f93025c08644" />

## 2. Overlapping Area Rate Boundary Polygons

One of the area rate boundary feature classes likely contains overlapping polygons. When a parcel falls within an overlap, the spatial overlay (Identity) assigns multiple area rate codes to the same PID. The SQL then selects only one of the rate codes (the record with the largest overlap area), which means the other valid rate code is silently dropped.

This can result in a property being assigned to the wrong area rate or missing from a rate it should belong to.

## 3. Parcel Fabric Is Frozen Per Season

Because the parcel fabric is live and can be edited by the Province at any time (see Issue #1 above), and because `area_rates.py` runs the same overlay analysis across many area rate feature classes over an extended period, using the live parcel fabric directly would risk each area rate table (`SAP_*`) being built against slightly different parcels.

To keep every table in a season's run built from an identical set of parcels:

- The first time `area_rates.py` runs for a season, it exports the live parcel fabric (`SDEADM.LND_parcels/SDEADM.LND_parcel_polygon`) once to a dated feature class (e.g. `Parcel_20260706`) in the run's local scratch geodatabase, via `get_parcels()`.
- The path to that dated export is recorded in `area_rates.ini` under `[Parcels] export_path`.
- Every subsequent run reads `export_path` from the config and reuses that exact snapshot instead of re-exporting from the live source, so results stay reproducible for the rest of the season.
- The dated snapshot is also copied into the run's final archive geodatabase (`archive_data()`), so the exact parcels behind a season's results are preserved alongside the final tables.

**To start a new season**, clear `export_path` in `area_rates.ini` (leave it blank) so the next run exports a fresh dated snapshot and records the new path.

This freeze is about consistency across a season's run — every `SAP_*` table is guaranteed to be built from the identical set of parcels. It does **not** address Issue #1's provincial timing gap, and it removes that issue's previous self-healing behavior within a season (see the note in Issue #1).

## 4. Tiny SHAPE_area Noise in Private Roads Results

`private_roads()` used to re-run `Identity_analysis` against the entire parcel fabric once per Area Rate code (22 times), which was slow. It now runs `Identity`/`Frequency` once against all 22 codes at once - the same approach `boundary_parcels()` uses for every other area rate type - then splits the combined result into the same per-code `SAP_PrivRd_{code}_compare` tables using cheap `TableSelect` calls instead of repeating the spatial overlay.

This was verified with `compare_private_roads.py` against the old per-code loop: every PID was assigned to the identical set of Area Rate codes in both versions. A handful of PIDs showed `SHAPE_area` differences of a few hundredths of a unit (on areas ranging from ~1 to ~100,000+ units) and `FREQUENCY` (fragment count) differences of 1-2 extra rows for the same PID/code. Both are expected: running Identity against all 22 codes' boundaries at once introduces extra vertices at shared/adjacent code edges, splitting some parcels into more slivers than the old per-code version did - but `Frequency_analysis` still sums those slivers into the same total area per PID/code either way. Neither is a real discrepancy in the billed area.

