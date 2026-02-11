# AAN to Parcel Fabric Lookup Cheatsheet

## Problem Statement

You have a list of **AANs (Assessment Account Numbers)** and need to:
1. Find which **PIDs** are associated with each AAN
2. Check if those PIDs exist in the **parcel fabric** (`LND_parcel_polygon`)

## The Challenge: Condo Units & Infant Parcels

**Key Insight:** Some PIDs won't be directly in `LND_parcel_polygon`:
- **CONDO UNIT PARCEL** - Individual condo units
- **INFANT PARCEL** - Newly created parcels

These use a **parent PID** (found in `LINNS_PIDRELATE.PIDRELATE`) to locate the parcel in the fabric.

---

## Data Flow

```
AAN (Account Number)
    ↓ [LINNS_PIDAANTAX]
PID (Parcel ID)
    ↓ [LINNS_PIDRELATE - check relationship]
    ├─ CONDO UNIT PARCEL → Use PIDRELATE (parent)
    ├─ INFANT PARCEL → Use PIDRELATE (parent)
    └─ Regular/NULL → Use PID directly
    ↓
Parcel Fabric PID
    ↓ [LND_parcel_polygon]
Parcel Geometry
```

---

## Quick Queries

### 1. Get PIDs from AANs

```sql
SELECT AAN, PID, TAXCONFIRM
FROM SDEADM.LINNS_PIDAANTAX
WHERE AAN IN ('05626617', '05709652', '06459072', ...);
```

---

### 2. Check if PIDs have relationships (Condo/Infant)

```sql
SELECT
    pt.AAN,
    pt.PID AS Unit_PID,
    pr.PIDRELATE AS Parent_PID,
    pr.RELNAME AS Relationship
FROM SDEADM.LINNS_PIDAANTAX pt
LEFT JOIN SDEADM.LINNS_PIDRELATE pr ON pt.PID = pr.PID
WHERE pt.AAN IN ('05626617', '05709652', '06459072', ...);
```

**Relationship Types:**
- `CONDO UNIT PARCEL` - Condo unit, use PIDRELATE for fabric lookup
- `INFANT PARCEL` - New parcel, use PIDRELATE for fabric lookup
- `CONDO COMMON PARCEL` - Common area, use this PID for fabric lookup
- `NULL` - Regular parcel, use PID directly

---

### 3. Determine Correct PID for Parcel Fabric Lookup

```sql
SELECT
    pt.AAN,
    pt.PID AS Original_PID,
    CASE
        WHEN pr.RELNAME IN ('CONDO UNIT PARCEL', 'INFANT PARCEL')
            THEN pr.PIDRELATE  -- Use parent
        ELSE pt.PID             -- Use original
    END AS Parcel_Fabric_PID,
    pr.RELNAME
FROM SDEADM.LINNS_PIDAANTAX pt
LEFT JOIN SDEADM.LINNS_PIDRELATE pr ON pt.PID = pr.PID
WHERE pt.AAN IN ('05626617', '05709652', '06459072', ...);
```

---

### 4. Check if in Parcel Fabric (LND_parcel_polygon)

```sql
WITH PID_Lookup AS (
    SELECT
        pt.AAN,
        pt.PID AS Original_PID,
        CASE
            WHEN pr.RELNAME IN ('CONDO UNIT PARCEL', 'INFANT PARCEL')
                THEN pr.PIDRELATE
            ELSE pt.PID
        END AS Parcel_Fabric_PID
    FROM SDEADM.LINNS_PIDAANTAX pt
    LEFT JOIN SDEADM.LINNS_PIDRELATE pr ON pt.PID = pr.PID
    WHERE pt.AAN IN ('05626617', '05709652', '06459072', ...)
)
SELECT
    pl.AAN,
    pl.Original_PID,
    pl.Parcel_Fabric_PID,
    CASE
        WHEN lpp.pid IS NOT NULL THEN 'YES - In Parcel Fabric'
        ELSE 'NO - Missing'
    END AS Status,
    lpp.SHAPE.STArea() AS Area
FROM PID_Lookup pl
LEFT JOIN SDEADM.LND_parcel_polygon lpp ON pl.Parcel_Fabric_PID = lpp.pid;
```

---

### 5. Find Missing PIDs (NOT in parcel fabric)

```sql
WITH PID_Lookup AS (
    SELECT
        pt.AAN,
        CASE
            WHEN pr.RELNAME IN ('CONDO UNIT PARCEL', 'INFANT PARCEL')
                THEN pr.PIDRELATE
            ELSE pt.PID
        END AS Parcel_Fabric_PID
    FROM SDEADM.LINNS_PIDAANTAX pt
    LEFT JOIN SDEADM.LINNS_PIDRELATE pr ON pt.PID = pr.PID
    WHERE pt.AAN IN ('05626617', '05709652', '06459072', ...)
)
SELECT pl.AAN, pl.Parcel_Fabric_PID, 'MISSING' AS Status
FROM PID_Lookup pl
LEFT JOIN SDEADM.LND_parcel_polygon lpp ON pl.Parcel_Fabric_PID = lpp.pid
WHERE lpp.pid IS NULL;
```

---

## Understanding Your Screenshot Results

From your query results, I can see:

| AAN | Original PID | Relationship | Parent PID (PIDRELATE) |
|-----|-------------|--------------|------------------------|
| 05626617 | 41556374 | INFANT PARCEL | 40194946 |
| 06459072 | 41556465 | INFANT PARCEL | 00368935 |
| 09419292 | 41559832 | CONDO UNIT PARCEL | 41554015 |
| 09419306 | 41559873 | CONDO UNIT PARCEL | 41554015 |
| 09419314 | 41559899 | CONDO UNIT PARCEL | 41554015 |
| 09419322 | 41559923 | CONDO UNIT PARCEL | 41554015 |
| 09507175 | 41553751 | INFANT PARCEL | 41083726 |
| 09512241 | 41559808 | CONDO UNIT PARCEL | 41554049 |
| 09512268 | 41559956 | CONDO UNIT PARCEL | 41554056 |

**What this means:**
- **Infant Parcels** (e.g., PID 41556374): Check if PID **40194946** exists in `LND_parcel_polygon`
- **Condo Unit Parcels** (e.g., PID 41559832): Check if PID **41554015** (common parcel) exists in `LND_parcel_polygon`

---

## Example: AAN 05626617

```sql
-- AAN 05626617 → PID 41556374 (INFANT PARCEL)
-- Parent PID: 40194946

-- Check if parent PID is in parcel fabric
SELECT pid, SHAPE.STArea() AS area
FROM SDEADM.LND_parcel_polygon
WHERE pid = 40194946;  -- Use PARENT PID, not 41556374
```

**If this returns 0 rows:** The parent parcel **40194946** is missing from `LND_parcel_polygon`.

---

## Example: AAN 09419292 (Condo)

```sql
-- AAN 09419292 → PID 41559832 (CONDO UNIT PARCEL)
-- Parent (Common Parcel) PID: 41554015

-- Check if common parcel is in parcel fabric
SELECT pid, SHAPE.STArea() AS area
FROM SDEADM.LND_parcel_polygon
WHERE pid = 41554015;  -- Use COMMON PARCEL PID, not unit PID
```

**If this returns 0 rows:** The common parcel **41554015** is missing from `LND_parcel_polygon`.

---

## Summary Logic Table

| Relationship Type | PID to Use in LND_parcel_polygon | Example |
|-------------------|----------------------------------|---------|
| `CONDO UNIT PARCEL` | PIDRELATE (parent/common parcel) | 41554015 |
| `INFANT PARCEL` | PIDRELATE (parent parcel) | 40194946 |
| `CONDO COMMON PARCEL` | PID (this is the parent) | Direct lookup |
| `NULL` (regular) | PID (direct lookup) | Direct lookup |

---

## Common Issues

### Issue 1: Condo Unit PID Not in Parcel Fabric
**Symptom:** Lookup with condo unit PID returns 0 rows
**Solution:** Use the **PIDRELATE** (common parcel PID) instead

### Issue 2: Infant Parcel Not in Parcel Fabric
**Symptom:** Lookup with infant PID returns 0 rows
**Solution:** Use the **PIDRELATE** (parent PID) instead

### Issue 3: Parent PID Also Missing
**Symptom:** Parent PID not in `LND_parcel_polygon`
**Possible Reasons:**
- Parcel created after GIS analysis was run
- Data sync issue between LINNS tables and parcel fabric
- Parent parcel was deleted/merged

---

## Files Available

1. **check_AANs_in_parcel_fabric.sql** - Complete automated script
2. **AAN_to_Parcel_Cheatsheet.md** - This reference guide (you are here)

---

## Next Steps

1. Run `check_AANs_in_parcel_fabric.sql` with your AAN list
2. Review **Step 6** output to see which PIDs are missing from parcel fabric
3. For missing PIDs:
   - Check if they're recent (created after last GIS run)
   - Verify parent PIDs exist in parcel fabric
   - Check if parcels need to be added to `LND_parcel_polygon`

---

**Created:** 2026-02-11
**Purpose:** Debug AAN → PID → Parcel Fabric lookups
