# AAN to PID to Parcel Fabric - Complete Logic Flow

## Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│ START: You have a list of AANs (Assessment Account Numbers)        │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 1: AAN → PID Lookup                                           │
│                                                                     │
│ Table: LINNS_PIDAANTAX                                             │
│ Query: SELECT PID FROM LINNS_PIDAANTAX WHERE AAN = 'xxxxxxxx'     │
│                                                                     │
│ Result: You get one or more PIDs associated with the AAN          │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 2: Check PID Relationship Type                               │
│                                                                     │
│ Table: LINNS_PIDRELATE                                             │
│ Query: SELECT PIDRELATE, RELNAME FROM LINNS_PIDRELATE             │
│        WHERE PID = [from Step 1]                                  │
│                                                                     │
│ Check RELNAME column:                                              │
│  ├─ 'CONDO UNIT PARCEL' → Go to Path A                           │
│  ├─ 'INFANT PARCEL' → Go to Path B                               │
│  ├─ 'CONDO COMMON PARCEL' → Go to Path C                         │
│  └─ NULL (no relationship) → Go to Path D                         │
└────────────────────────────┬────────────────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ PATH A          │ │ PATH B          │ │ PATH C & D      │
│ CONDO UNIT      │ │ INFANT PARCEL   │ │ COMMON/REGULAR  │
└─────────────────┘ └─────────────────┘ └─────────────────┘
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ Use PIDRELATE   │ │ Use PIDRELATE   │ │ Use PID         │
│ (parent/common  │ │ (parent parcel) │ │ (direct lookup) │
│  parcel)        │ │                 │ │                 │
└─────────────────┘ └─────────────────┘ └─────────────────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 3: Lookup in Parcel Fabric                                    │
│                                                                     │
│ Table: LND_parcel_polygon                                          │
│ Query: SELECT * FROM LND_parcel_polygon                            │
│        WHERE pid = [determined from Path A/B/C/D]                  │
│                                                                     │
│ Result:                                                             │
│  ├─ 1+ rows → ✓ PID exists in parcel fabric                       │
│  └─ 0 rows → ✗ PID NOT in parcel fabric (missing)                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Decision Tree

```
AAN (e.g., 05626617)
    │
    └─→ LINNS_PIDAANTAX.PID (e.g., 41556374)
            │
            └─→ Is this PID in LINNS_PIDRELATE?
                    │
                    ├─ NO (NULL) ────────────────────┐
                    │                                │
                    └─ YES → What is RELNAME?        │
                            │                        │
                            ├─ CONDO UNIT PARCEL     │
                            │  Use PIDRELATE          │
                            │  (e.g., 41554015) ──────┤
                            │                         │
                            ├─ INFANT PARCEL          │
                            │  Use PIDRELATE          │
                            │  (e.g., 40194946) ──────┤
                            │                         │
                            └─ CONDO COMMON PARCEL    │
                               Use PID directly ──────┤
                                                      │
                                                      ▼
                                        Check this PID in
                                        LND_parcel_polygon
```

---

## Real Examples from Your Data

### Example 1: Infant Parcel (AAN 05626617)

```
AAN: 05626617
  ↓ LINNS_PIDAANTAX
PID: 41556374
  ↓ LINNS_PIDRELATE
RELNAME: INFANT PARCEL
PIDRELATE: 40194946  ← USE THIS for parcel fabric lookup
  ↓
LND_parcel_polygon WHERE pid = 40194946
```

**SQL:**
```sql
-- Check if PARENT parcel 40194946 is in fabric
SELECT pid, SHAPE.STArea() AS area
FROM SDEADM.LND_parcel_polygon
WHERE pid = 40194946;
```

---

### Example 2: Condo Unit Parcel (AAN 09419292)

```
AAN: 09419292
  ↓ LINNS_PIDAANTAX
PID: 41559832 (unit)
  ↓ LINNS_PIDRELATE
RELNAME: CONDO UNIT PARCEL
PIDRELATE: 41554015  ← USE THIS (common parcel) for fabric lookup
  ↓
LND_parcel_polygon WHERE pid = 41554015
```

**SQL:**
```sql
-- Check if COMMON parcel 41554015 is in fabric
SELECT pid, SHAPE.STArea() AS area
FROM SDEADM.LND_parcel_polygon
WHERE pid = 41554015;
```

---

### Example 3: Multiple Condo Units, Same Common Parcel

```
AAN: 09419292 → PID: 41559832 ──┐
AAN: 09419306 → PID: 41559873   ├─→ All use PIDRELATE: 41554015
AAN: 09419314 → PID: 41559899   │   (same common parcel)
AAN: 09419322 → PID: 41559923 ──┘
```

**All 4 condo units share the same common parcel (41554015).**

**SQL:**
```sql
-- One query finds all 4 units
SELECT pid, SHAPE.STArea() AS area
FROM SDEADM.LND_parcel_polygon
WHERE pid = 41554015;  -- Common parcel covers all units
```

---

## SQL Pattern: The Universal Query

This single query handles **all relationship types**:

```sql
WITH PID_Lookup AS (
    -- Step 1: Get PID from AAN
    SELECT
        pt.AAN,
        pt.PID AS Original_PID,
        pr.RELNAME AS Relationship,
        pr.PIDRELATE AS Parent_PID,
        -- Step 2: Determine which PID to use for fabric lookup
        CASE
            WHEN pr.RELNAME IN ('CONDO UNIT PARCEL', 'INFANT PARCEL')
                THEN pr.PIDRELATE  -- Use parent
            ELSE pt.PID             -- Use original
        END AS Parcel_Fabric_PID
    FROM SDEADM.LINNS_PIDAANTAX pt
    LEFT JOIN SDEADM.LINNS_PIDRELATE pr ON pt.PID = pr.PID
    WHERE pt.AAN = '05626617'  -- Replace with your AAN
)
-- Step 3: Check if in parcel fabric
SELECT
    pl.*,
    CASE
        WHEN lpp.pid IS NOT NULL THEN 'In Fabric'
        ELSE 'Missing'
    END AS Status,
    lpp.SHAPE.STArea() AS Area
FROM PID_Lookup pl
LEFT JOIN SDEADM.LND_parcel_polygon lpp
    ON pl.Parcel_Fabric_PID = lpp.pid;
```

---

## Troubleshooting Guide

### Scenario 1: PID in LINNS_PIDAANTAX but NOT in LND_parcel_polygon

**Check:**
1. Is it a condo unit or infant parcel?
   ```sql
   SELECT RELNAME, PIDRELATE FROM LINNS_PIDRELATE WHERE PID = [your_pid];
   ```
2. If yes, are you using the PARENT PID (PIDRELATE) for lookup?
3. If no relationship, check if parcel was created recently (after last GIS run)

---

### Scenario 2: Parent PID (PIDRELATE) Also Missing

**Possible Causes:**
- Parent parcel created after GIS analysis
- Parent parcel merged/deleted
- Data sync issue between LINNS and parcel fabric

**Next Steps:**
- Check creation date: `SELECT CRE_DATE FROM LINNS_PIDRELATE WHERE PID = [unit_pid]`
- Compare to last GIS run date
- Check if parent exists elsewhere: `SELECT * FROM LINNS_PIDAANTAX WHERE PID = [parent_pid]`

---

### Scenario 3: AAN Has Multiple PIDs

**This is normal for:**
- Properties with multiple parcels
- Condo buildings (each unit has a PID, all share an AAN)
- Parent/child parcel relationships

**Example from your data:**
```
AAN 09512241 might have:
  ├─ Unit 1 (PID 41559808)
  ├─ Unit 2 (PID 41559809)
  └─ Common Parcel (PID 41554049)
```

**Handle by:** Check each PID individually using the logic flow above.

---

## Summary Table: Which PID to Use

| RELNAME (from LINNS_PIDRELATE) | PID to Use in LND_parcel_polygon | Column Name |
|-------------------------------|----------------------------------|-------------|
| `CONDO UNIT PARCEL` | PIDRELATE | Parent/Common Parcel |
| `INFANT PARCEL` | PIDRELATE | Parent Parcel |
| `CONDO COMMON PARCEL` | PID | This IS the parent |
| `NULL` (no relationship) | PID | Direct lookup |
| Any other value | PID | Direct lookup (default) |

---

## Files in This Toolkit

1. **check_AANs_in_parcel_fabric.sql** - Automated multi-step query
2. **AAN_to_Parcel_Cheatsheet.md** - Quick reference queries
3. **AAN_to_PID_Logic_Flow.md** - This file (visual flow)

---

## Quick Command Reference

```sql
-- 1. Get PID from AAN
SELECT PID FROM LINNS_PIDAANTAX WHERE AAN = 'xxxxxxxx';

-- 2. Check relationship
SELECT RELNAME, PIDRELATE FROM LINNS_PIDRELATE WHERE PID = xxxxxxxx;

-- 3. Check in parcel fabric
SELECT * FROM LND_parcel_polygon WHERE pid = xxxxxxxx;

-- 4. All-in-one (using CASE logic)
SELECT
    CASE
        WHEN pr.RELNAME IN ('CONDO UNIT PARCEL', 'INFANT PARCEL')
            THEN pr.PIDRELATE
        ELSE pt.PID
    END AS Use_This_PID
FROM LINNS_PIDAANTAX pt
LEFT JOIN LINNS_PIDRELATE pr ON pt.PID = pr.PID
WHERE pt.AAN = 'xxxxxxxx';
```

---

**Last Updated:** 2026-02-11
**Purpose:** Visual guide for AAN → PID → Parcel Fabric lookups
