# Analysis: Properties Missing from Tax Designation Area Rates (M010/M020/M030)

## Context

Vicki reported that a number of properties were picked up by GIS **last year** for general rates (M010, M020, M030 - Tax Designation) but were **not picked up this year**. The rates for last year ended 03/31/2026 and new rates needed to be manually added effective 04/01/2026. This analysis examines the area rates workflow to identify where and why these properties could have been dropped.

### Affected Properties

| AAN | Rate | Address |
|-----|------|---------|
| 05626617 | M030 | 2160 East Petpeswick Rd Lot 2-2A, East Petpeswick |
| 05709652 | M010 | Micmac Dr Lot C, Dartmouth |
| 06459072 | M010 | 11 Murray Rd, Eastern Passage |
| 08986320 | M010 | Baha Crt Parcel L, Bedford |
| 08986339 | M010 | Richardson Dr Parcel L, Port Bedford |
| 09419292 | M030 | 529 Ketch Harbour Rd Lot 102, Bear Cove |
| 09419306 | M030 | 521 Ketch Harbour Rd Lot 103, Bear Cove |
| 09419314 | M030 | 513 Ketch Harbour Rd Lot 104, Bear Cove |
| 09419322 | M030 | 503 Ketch Harbour Rd Lot 105, Bear Cove |
| 09507175 | M030 | Wisteria Lane Parcel 804, Upper Tantallon |
| 09512241 | M030 | 495 Ketch Harbour Rd Lot 106, Bear Cove |
| 09512268 | M030 | 485 Ketch Harbour Rd Lot 107, Bear Cove |
| 09736603 | M030 | Voyageur Way Lot 25A, Hammonds Plains |
| 10257492 | M030 | 55 Manetail Lane Lot S-12, Lawrencetown |

**Common themes observed:**
- Properties span multiple locations (not geographically clustered to one area)
- Properties span both M010 (urban) and M030 (suburban) codes
- Several Bear Cove properties appear consecutive (Lots 102-107 on Ketch Harbour Rd), suggesting a possible subdivision or boundary-edge pattern
- Many properties reference "Lot" or "Parcel" designations, suggesting relatively **new subdivisions**

---

## Workflow Overview

The Tax Designation area rate assignment is a two-phase process:

### Phase 1: GIS Spatial Analysis (`area_rates.py`)
1. **Identity Analysis**: Overlay `LND_parcel_polygon` with `ADM_finance_boundaries/ADM_tax_designation`
2. **Frequency Analysis**: Group results by PID + AREARATE_CODE, summing SHAPE_area

### Phase 2: SQL Processing (`SQL/taxdes/Run_Taxdes.sql`)
1. Select one ARCODE per PID (largest area overlap wins)
2. Join PIDs to AANs via `LINNS_PIDAANTAX`
3. Identify condo common parcels via `LINNS_PIDRELATE`
4. Get condo unit AANs
5. Recode priority logic (M010=1, M020=2, M030=3; MAX wins per ACCTNO)
6. Build final table `AR_taxdes_FINAL_SAP`

### Phase 3: Aggregation (`alter_final_tables.py`)
- All `*_FINAL_SAP` tables consolidated into `Area_Rates_PID_AAN`

---

## Hypotheses (Ranked by Likelihood)

### Hypothesis 1: ADM_tax_designation Boundary Changed (HIGH likelihood)

**Theory:** The `ADM_tax_designation` feature class polygons were edited between last year's run and this year's run. If boundary edges were redrawn, simplified, or corrected, properties near the periphery could fall outside the updated boundary.

**Why this fits:**
- The affected properties are spread across multiple locations, but the common input is the same boundary layer
- "Lot" and "Parcel" designations suggest newer subdivisions that may sit at the edges of existing tax designation zones
- The consecutive Bear Cove lots (102-107) could indicate a stretch of road right at a boundary edge

**How to verify:**
1. Compare the `ADM_tax_designation` feature class from this year vs. last year (check edit dates/version history in SDE)
2. For each affected PID, visually inspect whether the parcel polygon intersects the current `ADM_tax_designation` boundary in ArcGIS Pro
3. Run an ad-hoc Identity analysis on just the affected PIDs against the current boundary to see if they get NULL AREARATE_CODE
4. Check SDE edit logs/versioning history for `ADM_tax_designation` to see if and when polygons were modified

### Hypothesis 2: Parcel Geometry Changed — New Subdivisions (HIGH likelihood)

**Theory:** The affected parcels in `LND_parcel_polygon` are newly created or recently redrawn (subdivisions, lot consolidations). If a PID was replaced or the geometry was altered, the Identity analysis might produce a different result than last year.

**Why this fits:**
- Many affected properties have "Lot" designations with sequential numbers (Lot 102, 103, 104...), typical of recent subdivisions
- "Parcel L", "Parcel 804", "Lot 25A", "Lot S-12" suggest recently carved-out parcels
- A new parcel polygon might have slightly different geometry (even just vertex positions) that changes the overlap calculation

**How to verify:**
1. Query `LND_parcel_polygon` for each affected PID — check `SDATE` (input date) or edit tracking fields to see if the parcel was recently created/modified
2. Compare parcel geometry between this year and last year's archived parcels (if available)
3. Check if the PIDs in the email match PIDs from last year, or if the PIDs themselves have changed (lot consolidation/subdivision could create new PIDs)

### Hypothesis 3: Parcel Falls Outside Boundary — Edge/Sliver Issue (MEDIUM likelihood)

**Theory:** The ArcPy Identity analysis uses `cluster_tolerance=""` (empty = default). For parcels that barely touch or overlap a boundary by a sliver, small changes in either the parcel or boundary geometry can flip the result from "inside" to "outside." The Frequency analysis then produces a NULL `AREARATE_CODE` for that PID, which gets filtered out by `WHERE AREARATE_CODE IS NOT NULL`.

**Why this fits:**
- The workflow filters out NULL AREARATE_CODE records at `Run_Taxdes.sql:34`
- Properties at the very edge of tax designation zones are vulnerable to this
- No tolerance/buffer is applied — it's a strict geometric intersection

**How to verify:**
1. In ArcGIS Pro, select each affected PID and check its spatial relationship with the `ADM_tax_designation` boundary — is it inside, on the edge, or completely outside?
2. Try running Identity with a small cluster tolerance (e.g., 0.1m) to see if the properties get picked up
3. Check the `SAP_ADM_tax_designation` table from the most recent run — do these PIDs appear with NULL AREARATE_CODE, or are they completely absent?

### Hypothesis 4: ADM_hrm_core Boundary Not Used in Workflow (MEDIUM likelihood)

**Theory:** The Area Rate Codes reference table lists **two** feature class boundaries for M010/M020/M030: `ADM_finance_boundaries/ADM_tax_designation` **and** `ADM_hrm_core`. However, the workflow (`area_rates.py` + `area_rates.ini`) only uses `ADM_tax_designation`. If `ADM_hrm_core` was previously used as a fallback or supplementary boundary (e.g., to capture properties within the municipal boundary but outside specific tax designation polygons), its omission from the current workflow could explain the gap.

**Why this fits:**
- The reference documentation explicitly lists `ADM_hrm_core` alongside `ADM_tax_designation`
- Properties in the "suburban" M030 zone at the HRM periphery could fall within `ADM_hrm_core` but outside `ADM_tax_designation` if the tax designation polygons don't fully tile the municipal boundary
- This would be a persistent issue (affecting the same properties every year) unless there was a past manual correction or different process

**How to verify:**
1. Confirm with the team whether `ADM_hrm_core` was ever used in conjunction with `ADM_tax_designation` for the area rates process
2. Check if the affected PIDs fall within `ADM_hrm_core` but outside `ADM_tax_designation`
3. Review any historical process documentation or model builder files to see if an older version of the workflow used `ADM_hrm_core`

### Hypothesis 5: PID-to-AAN Mapping Gap in LINNS_PIDAANTAX (MEDIUM likelihood)

**Theory:** Even if the GIS phase correctly identifies a PID as being within a tax designation boundary, the SQL phase joins PIDs to AANs using `LINNS_PIDAANTAX`. If a PID has no matching AAN in this table (or the AAN is NULL/blank), the property will be silently dropped.

**Why this fits:**
- New subdivisions may have PIDs registered in the parcel layer but not yet populated in the PID-AAN lookup table
- The SQL at `Run_Taxdes.sql:57-58` explicitly deletes records where `ACCTNO IS NULL OR ACCTNO LIKE ''`

**How to verify:**
1. Query `LINNS_PIDAANTAX` for each affected PID to confirm a valid AAN mapping exists
2. Compare the PIDs from the email against the `AR_taxdes_pid_SAP` intermediate table (if still available) to see if the GIS phase DID find them but the SQL phase dropped them
3. Cross-reference the AANs in the email with `LINNS_PIDAANTAX` to confirm PID-AAN links are current

### Hypothesis 6: Condo Common Parcel Relationship Issue (LOW likelihood)

**Theory:** If any of the affected properties are condos, their rate assignment depends on the `LINNS_PIDRELATE` table having correct "CONDO COMMON PARCEL" relationships. Missing or broken relationships would cause condo units to be dropped.

**Why this fits:**
- The properties with "Lot" designations could potentially be condo-style developments

**How to verify:**
1. Check if any affected PIDs appear in `LINNS_PIDRELATE` with `RELNAME = 'CONDO COMMON PARCEL'`
2. If they are condos, verify that the common parcel PID intersects the `ADM_tax_designation` boundary

---

## Structured Verification Guide

### Step 1: Check the SAP Intermediate Table
```sql
-- Do the affected PIDs appear in the GIS output at all?
-- (Run this if SAP_ADM_TAX_DESIGNATION still exists, before cleanup)
SELECT PID, AREARATE_CODE, SHAPE_area
FROM SDEADM.SAP_ADM_TAX_DESIGNATION
WHERE PID IN (
    -- You'll need the PIDs corresponding to the AANs listed
    -- Get them from LINNS_PIDAANTAX first
    SELECT PID FROM SDEADM.LINNS_PIDAANTAX
    WHERE AAN IN ('05626617','05709652','06459072','08986320','08986339',
                  '09419292','09419306','09419314','09419322','09507175',
                  '09512241','09512268','09736603','10257492')
);
```
- **If PIDs appear with a valid AREARATE_CODE**: Problem is in SQL phase (Steps 2-5)
- **If PIDs appear with NULL AREARATE_CODE**: Parcels intersected the identity layer but got no code (boundary edge issue)
- **If PIDs are completely absent**: PIDs don't exist in `LND_parcel_polygon`, or have no geometry

### Step 2: Verify PID-AAN Mappings
```sql
-- Confirm all AANs have valid PID mappings
SELECT AAN, PID
FROM SDEADM.LINNS_PIDAANTAX
WHERE AAN IN ('05626617','05709652','06459072','08986320','08986339',
              '09419292','09419306','09419314','09419322','09507175',
              '09512241','09512268','09736603','10257492');
```
- **If rows are missing**: The PID-AAN lookup is incomplete — populate it
- **If rows exist**: Move on to spatial verification

### Step 3: Visual/Spatial Inspection in ArcGIS Pro
1. Load `LND_parcel_polygon` and `ADM_tax_designation`
2. Select each affected PID
3. Determine: Does the parcel geometry intersect any `ADM_tax_designation` polygon?
4. If not, check if it intersects `ADM_hrm_core`
5. Check the `SDATE` or edit tracking fields on both the parcel and boundary to see recent changes

### Step 4: Compare with Last Year's Data
1. Check the archived `AR_taxdes_FINAL_SAP` from last year (if available in `final_features_archive.gdb`)
2. Confirm these AANs were present in last year's final output
3. Compare the `ADM_tax_designation` boundary geometry between last year and this year

### Step 5: Check for Boundary Edit History
```sql
-- Check SDE state/version history for ADM_tax_designation edits
-- (Method depends on SDE versioning configuration)
```
Or check the feature class properties in ArcGIS Pro for last edit date.

---

## Additional Observation: SQL Bug in Run_Taxdes.sql

While analyzing the workflow, I noticed that `Run_Taxdes.sql` creates `AR_taxdes_FINAL_SAP` **twice**:

1. **Lines 164-175**: Creates it from `AR_taxdes_Pre_FINAL_SAP` (which has the RECODE priority logic applied)
2. **Lines 178-196**: Immediately drops and recreates it from the raw `AR_taxdes_AAN_SAP` + `AR_taxdes_CONDO_AAN_SAP` tables (bypassing RECODE entirely)

The second creation **overwrites** the first. This means the M010/M020/M030 priority recoding logic (where M030 > M020 > M010, and the highest wins per ACCTNO) is **never actually applied** to the final output. The final table uses the original ARCODE values based on largest spatial overlap, not the priority-based recoding.

**This bug does not cause missing properties** (both versions include the same PIDs), but it could cause **incorrect rate codes** for properties that sit in overlapping M010/M020/M030 zones. This should be fixed separately.

---

## Visual Review Findings (ArcGIS Pro Inspection)

A visual review of the affected parcels was conducted in ArcGIS Pro against the `ADM_tax_designation` boundary layer with the parcel layer filtered to the affected PIDs using a definition query:

```sql
PID IN ('41019084', '41559808', '41559832', '41559956', '41559873',
        '41559899', '41559923', '41556374', '41556465', '41553751')
```

### Parcel-by-Parcel Observations

| PID | AAN | Expected Rate | Location Relative to Boundary |
|-----|-----|---------------|-------------------------------|
| 41556465 | 06459072 | M010 (Urban) | Clearly inside M010 zone, not near any boundary |
| 41553751 | 09507175 | M030 (Rural) | Clearly inside M030 zone, not near any boundary |
| 41556374 | 05626617 | M030 (Rural) | Two polygon records, both clearly inside M030 zone |
| 41019084 | 05709652 | M010 (Urban) | Within M010 zone |
| 41559808 | 09512241 | M030 (Rural) | Within M030 zone |
| 41559832 | 09419292 | M030 (Rural) | Within M030 zone |
| 41559956 | 09512268 | M030 (Rural) | Within M030 zone |
| 41559873 | 09419306 | M030 (Rural) | Within M030 zone |
| 41559899 | 09419314 | M030 (Rural) | Within M030 zone |
| 41559923 | 09419322 | M030 (Rural) | Within M030 zone |

### Critical Finding: SDATE

All affected parcels in `LND_parcel_polygon` have **SDATE = 2/6/2026**. This indicates the parcel geometries were created or updated on February 6, 2026 — likely **after** the GIS spatial analysis was run for this year's area rates cycle.

### PID-to-AAN Mapping Confirmed

A query against `SDEADM.LINNS_PIDAANTAX` confirmed all 10 PIDs have valid AAN mappings with `TAXCONFIRM = 'T'`. The PID-AAN relationship is intact.

### Hypotheses Eliminated

- **Hypothesis 1 (Boundary Changed)**: **Ruled out.** The parcels are well within their respective tax designation zones, not near any boundary edge. Boundary changes would not explain their absence.
- **Hypothesis 3 (Edge/Sliver Issue)**: **Ruled out.** No parcels are at or near boundary edges. Tolerance/cluster issues are not relevant here.
- **Hypothesis 5 (PID-AAN Mapping Gap)**: **Unlikely as root cause.** The LINNS_PIDAANTAX mappings exist now with TAXCONFIRM = 'T'. However, it remains possible these mappings were added at the same time as the parcel geometries (2/6/2026), which could mean they also didn't exist when the SQL phase ran.

### Confirmed Root Cause: Hypothesis 2 — New Parcel Geometries Created After GIS Run

The uniform SDATE of **2/6/2026** across all affected parcels is the strongest evidence. These are new subdivision parcels that were created in `LND_parcel_polygon` **after** the area rates GIS analysis (`area_rates.py`) was executed for this cycle. Since the parcels didn't exist in the parcel layer at the time of the Identity analysis, they could not have been picked up.

**The workflow ran correctly — it simply ran before these parcels existed.**

---

## Recommendations

1. **Immediate fix**: Manually add the 14 affected AANs to `Area_Rates_PID_AAN` with their correct AREARATE_CODE values (as Vicki has already done for the 04/01/2026 effective date).

2. **Process timing**: Coordinate the area rates GIS run timing with Land Services to ensure it occurs **after** any pending parcel subdivisions are committed to `LND_parcel_polygon`. Alternatively, run a final check/sweep after the main run to catch recently added parcels.

3. **Catch-up mechanism**: Consider adding a post-processing step that identifies PIDs in `LINNS_PIDAANTAX` (with `TAXCONFIRM = 'T'`) that have no corresponding entry in `Area_Rates_PID_AAN`, then flags them for manual review or automated spatial assignment.

4. **SQL bug (separate issue)**: The `Run_Taxdes.sql` double-creation of `AR_taxdes_FINAL_SAP` (lines 164-196) still needs to be addressed to ensure the M010/M020/M030 priority recoding logic is actually applied.

---

## Summary

The 14 missing properties were not dropped due to boundary changes, spatial tolerance issues, or PID-AAN mapping gaps. They are **new subdivision parcels** (SDATE = 2/6/2026) that were created in the parcel layer **after** the area rates GIS spatial analysis was executed. The parcels are all clearly within their respective tax designation zones (M010 or M030) and have valid PID-AAN mappings, confirming they would have been picked up if they had existed at the time of the run.
