# PID Debugging Guide for PID 41019084

## Overview

This guide helps you track **PID 41019084** through the Area Rates processing pipeline to identify exactly where it gets dropped.

---

## Files Created for You

### 1. **PID_TRACKING_CHEATSHEET.md**
A comprehensive reference guide with:
- Complete data flow explanation
- SQL queries for each checkpoint
- Common failure points and fixes
- Instructions for tracking ANY PID through the process

**Use this for:** General reference and debugging any PID in the future

---

### 2. **track_pid_41019084.sql**
A ready-to-run SQL script specifically for PID 41019084 that:
- Checks all 10 checkpoints automatically
- Shows exactly where the PID exists and where it drops off
- Includes helpful status messages
- Provides a summary table at the end

**Use this for:** Quick diagnosis of PID 41019084

---

## Quick Start: Track PID 41019084

### Step 1: Run the Tracking Script

```bash
# Execute the SQL script in your database
sqlcmd -S your_server -d your_database -i track_pid_41019084.sql -o pid_41019084_results.txt
```

Or in SQL Server Management Studio (SSMS):
1. Open `track_pid_41019084.sql`
2. Connect to your database
3. Execute (F5)
4. Review results

---

### Step 2: Interpret the Results

The script will show output for each checkpoint. Look for the **first place where you get 0 rows**.

#### Example Output Analysis:

```
CHECKPOINT 0: LND_parcel_polygon
✓ Result: 1 row (PID exists in source)

CHECKPOINT 1: SAP_ADM_TAX_DESIGNATION
✓ Result: 2 rows (PID overlaps 2 tax designation zones)

CHECKPOINT 2: AR_taxdes_pid_SAP
✓ Result: 1 row (Largest overlap selected, PID=41019084, ARCODE=M010)

CHECKPOINT 3: LINNS_PIDAANTAX
✗ Result: 0 rows *** PID NOT IN LOOKUP TABLE ***

CHECKPOINT 4: AR_taxdes_AAN_SAP
✗ Result: 0 rows (Filtered out - no AAN mapping)

CHECKPOINT 9: Area_Rates_PID_AAN
✗ Result: 0 rows (Never made it to final table)
```

**Diagnosis:** PID 41019084 was dropped at **Checkpoint 3** because it's **missing from the LINNS_PIDAANTAX lookup table**.

---

## Common Scenarios & Solutions

### Scenario 1: PID Missing from LINNS_PIDAANTAX (Most Common)

**Symptom:**
- ✓ Checkpoint 0-2 show data
- ✗ Checkpoint 3 shows 0 rows
- ✗ Checkpoint 4+ show 0 rows

**Root Cause:** PID doesn't have an Account Number (AAN) mapping

**Solutions:**
1. Check if PID is valid/active in the tax system
2. Update LINNS_PIDAANTAX with the correct PID→AAN mapping
3. If PID should be exempt, add to exclusion list

**Query to investigate:**
```sql
-- Check if PID exists in related lookup tables
SELECT * FROM [other_pid_lookup_tables] WHERE pid = 41019084;

-- Check if PID is in a different status table
SELECT * FROM [status_tables] WHERE pid = 41019084;
```

---

### Scenario 2: PID Doesn't Intersect Area Rate Boundary

**Symptom:**
- ✓ Checkpoint 0 shows data
- ✗ Checkpoint 1 shows 0 rows for all area rate types

**Root Cause:** PID parcel geometry doesn't overlap with any area rate boundaries

**Solutions:**
1. Verify parcel geometry is valid
2. Check if area rate boundaries are correct
3. Confirm PID should actually be in an area rate zone

**Query to investigate:**
```sql
-- Check parcel geometry
SELECT pid, SHAPE.STIsValid() as IsValid, SHAPE.STArea() as Area
FROM LND_parcel_polygon
WHERE pid = 41019084;

-- Check spatial relationship with boundaries
SELECT ar.AREARATE_CODE,
       p.SHAPE.STIntersects(ar.SHAPE) as Intersects,
       p.SHAPE.STIntersection(ar.SHAPE).STArea() as OverlapArea
FROM LND_parcel_polygon p
CROSS JOIN ADM_tax_designation ar
WHERE p.pid = 41019084;
```

---

### Scenario 3: NULL AREARATE_CODE

**Symptom:**
- ✓ Checkpoint 1 shows rows BUT AREARATE_CODE IS NULL
- ✗ Checkpoint 2 shows 0 rows

**Root Cause:** Area rate boundary feature has NULL/blank code values

**Solutions:**
1. Check area rate boundary feature attributes
2. Update boundary feature with correct AREARATE_CODE values
3. Re-run GIS analysis

---

### Scenario 4: Condo Common Parcel Issues

**Symptom:**
- ✓ Checkpoint 5 shows PID is a condo common parcel
- ✗ Checkpoint 7 shows 0 rows (no condo unit AANs)

**Root Cause:** Condo unit PIDs (PIDRELATE) don't have AANs in LINNS_PIDAANTAX

**Solutions:**
1. Check LINNS_PIDAANTAX for unit PIDs
2. Update lookup table with unit PID→AAN mappings

**Query to investigate:**
```sql
-- Get all unit PIDs for this common parcel
SELECT pid as Common_PID, PIDRELATE as Unit_PID, RELNAME
FROM linns_pidrelate
WHERE pid = 41019084 AND RELNAME = 'CONDO COMMON PARCEL';

-- Check which units have AANs
SELECT pr.PIDRELATE as Unit_PID, pa.AAN
FROM linns_pidrelate pr
LEFT JOIN LINNS_PIDAANTAX pa ON pr.PIDRELATE = pa.pid
WHERE pr.pid = 41019084 AND pr.RELNAME = 'CONDO COMMON PARCEL';
```

---

## Understanding the Pipeline

### Phase 1: GIS Spatial Analysis (`area_rates.py`)
- **Input:** `LND_parcel_polygon` + Area Rate Boundaries
- **Process:** Identity Analysis + Frequency Analysis
- **Output:** `SAP_*` tables (e.g., `SAP_ADM_TAX_DESIGNATION`, `SAP_bid`)

### Phase 2: SQL Processing (6 Steps per Area Rate Type)
- **Step 1:** Select PID → ARCODE (largest overlap, filter NULLs)
- **Step 2:** Join PID → AAN via `LINNS_PIDAANTAX` **← MOST COMMON FAILURE POINT**
- **Step 3:** Identify condo common parcels
- **Step 4:** Get AANs for condo units
- **Step 5:** Combine non-condo + condo records
- **Step 6:** Cleanup (drop intermediate tables)

### Phase 3: Aggregation (`alter_final_tables.py`)
- **Input:** All `*_FINAL_SAP` tables
- **Output:** `Area_Rates_PID_AAN` (master aggregate table)

### Phase 4: Removals (`remove_pids.sql`)
- **Explicit removals:** PIDs with `AREARATE_CODE LIKE 'M060'`

---

## Data Flow Diagram

```
LND_parcel_polygon (41019084)
    ↓
SAP_ADM_TAX_DESIGNATION (PID, AREARATE_CODE, shape_area)
    ↓ [Step 1: Keep largest overlap, filter NULLs]
AR_taxdes_pid_SAP (PID, ARCODE, AREA)
    ↓ [Step 2: JOIN with LINNS_PIDAANTAX] ← **CHECKPOINT 3: LOOKUP FAILURE**
AR_taxdes_AAN_SAP (PID, ACCTNO, ARCODE)
    ↓ [Step 3-4: Condo processing if applicable]
AR_taxdes_CONDO_* (optional)
    ↓ [Step 5: Combine all records]
AR_taxdes_FINAL_SAP (PID, ACCTNO, ARCODE)
    ↓ [Aggregation: All area rates combined]
Area_Rates_PID_AAN (PID, AAN, AREARATE_CODE, TAXYEAR)
    ↓ [Removals: Filter M060]
[Final Output]
```

---

## Critical Lookup Tables

### LINNS_PIDAANTAX (PID → Account Number Mapping)
- **Purpose:** Maps PID to AAN (Account Number)
- **Why Critical:** Required for Step 2 in ALL area rate types
- **Failure Impact:** PID dropped completely if not in this table

```sql
-- Check your PID
SELECT * FROM LINNS_PIDAANTAX WHERE pid = 41019084;
```

### LINNS_PIDRELATE (Condo Relationships)
- **Purpose:** Maps condo common parcels to unit PIDs
- **Why Critical:** Required for condo processing (Steps 3-4)
- **Failure Impact:** Condo units won't get area rate assignments

```sql
-- Check if your PID is a condo
SELECT * FROM linns_pidrelate
WHERE pid = 41019084 AND RELNAME = 'CONDO COMMON PARCEL';
```

---

## Validation Checklist

Before running the process, verify:

- [ ] PID exists in `LND_parcel_polygon`
- [ ] PID has valid geometry (not NULL, IsValid = 1)
- [ ] PID exists in `LINNS_PIDAANTAX` with non-NULL AAN
- [ ] PID spatially intersects at least one area rate boundary
- [ ] Area rate boundary features have non-NULL AREARATE_CODE values
- [ ] If condo: Unit PIDs exist in `LINNS_PIDAANTAX`

---

## Next Steps

1. **Run the tracking script:** `track_pid_41019084.sql`
2. **Find the checkpoint where RecordCount = 0**
3. **Refer to "Common Scenarios" section above**
4. **Fix the underlying issue** (update lookup tables, fix geometry, etc.)
5. **Re-run the area rates process**
6. **Verify PID appears in `Area_Rates_PID_AAN`**

---

## Additional Resources

- **Cheatsheet:** `PID_TRACKING_CHEATSHEET.md` - Full reference guide
- **Tracking Script:** `track_pid_41019084.sql` - Automated checkpoint queries
- **SQL Files:** `SQL/[area_rate_type]/` - Individual step scripts
- **Configuration:** `area_rates.ini` - Active area rate types
- **Main Script:** `area_rates.py` - GIS processing orchestration

---

## Getting Help

If you're still stuck after following this guide:

1. Check the full output of `track_pid_41019084.sql`
2. Review the "Common Failure Points" table in `PID_TRACKING_CHEATSHEET.md`
3. Examine the specific SQL file for the failing step (e.g., `ar_taxdes2_AAN_SAP.sql`)
4. Verify data quality in lookup tables
5. Check GIS analysis output in `SAP_*` tables

---

**Last Updated:** 2026-02-10
**PID Tracked:** 41019084
