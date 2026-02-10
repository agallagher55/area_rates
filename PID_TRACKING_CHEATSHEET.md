# PID Tracking Cheatsheet
## How to Debug Where a PID Gets Dropped in the Area Rates Process

**Example PID:** 41019084

This cheatsheet walks you through tracking a PID from `LND_parcel_polygon` through all intermediate tables to the final `Area_Rates_PID_AAN` table.

---

## **Data Flow Overview**

```
LND_parcel_polygon
    ↓ [GIS Identity/Frequency Analysis]
SAP_[AreaRateType] (e.g., SAP_ADM_TAX_DESIGNATION, SAP_bid, SAP_TRANSIT)
    ↓ [Step 1: PID → ARCODE Selection]
AR_[type]_pid_SAP
    ↓ [Step 2: PID → AAN Mapping]
AR_[type]_AAN_SAP
    ↓ [Step 3-4: Condo Processing]
AR_[type]_CONDO_in_SAP → AR_[type]_CONDO_AAN_SAP
    ↓ [Step 5: Combine Non-Condo + Condo]
AR_[type]_FINAL_SAP
    ↓ [Consolidation]
Area_Rates_PID_AAN
    ↓ [Removals]
[Final Output]
```

---

## **Active Area Rate Types**

Based on `area_rates.ini`, the following area rate types are processed:

| Area Rate Type | Table Prefix | Feature Layer |
|----------------|--------------|---------------|
| Tax Designation | `taxdes` | `ADM_tax_designation` |
| BID | `bid` | `LND_area_rate_bid` |
| Transit | `TRANSIT` | `LND_area_rate_transit` |
| Active Transit | `active_trans` | `LND_area_rate_active_trans` |
| Fire Protection | `FIRE_PROTECTION` | `LND_area_rate_fire_protection` |
| Commercial Facilities | `ComFacServ` | `LND_area_rate_ComFac_Serv` |
| Commercial | `commercial` | `LND_area_rate_commercial` |
| Stormwater | `stormwater` | `LND_area_rate_stormwater` |
| Private Road | `Priv_Road` | `LND_area_rate_Priv_Road` |

**Note:** Each area rate type follows the same 6-step processing pattern.

---

## **STEP-BY-STEP PID TRACKING QUERIES**

Replace `41019084` with your PID of interest in all queries below.

---

### **CHECKPOINT 0: Verify PID Exists in Source Data**

```sql
-- Check if PID exists in the master parcel layer
SELECT pid, SHAPE.STArea() as area
FROM LND_parcel_polygon
WHERE pid = 41019084;
```

**Expected Result:** 1 row
**If 0 rows:** PID doesn't exist in source data - process cannot proceed

---

### **CHECKPOINT 1: Check SAP Tables (After GIS Analysis)**

For each area rate type, check if the PID appears in the spatial analysis output:

```sql
-- Tax Designation
SELECT * FROM SAP_ADM_TAX_DESIGNATION WHERE PID = 41019084;

-- BID
SELECT * FROM SAP_bid WHERE PID = 41019084;

-- Transit
SELECT * FROM SAP_TRANSIT WHERE PID = 41019084;

-- Active Transit
SELECT * FROM SAP_active_trans WHERE PID = 41019084;

-- Fire Protection
SELECT * FROM SAP_FIRE_PROTECTION WHERE PID = 41019084;

-- Commercial Facilities
SELECT * FROM SAP_ComFacServ WHERE PID = 41019084;

-- Commercial
SELECT * FROM SAP_commercial WHERE PID = 41019084;

-- Stormwater
SELECT * FROM SAP_stormwater WHERE PID = 41019084;

-- Private Road
SELECT * FROM SAP_Priv_Road WHERE PID = 41019084;
```

**Expected Result:** 1+ rows per area rate type
**If 0 rows:** PID doesn't spatially intersect that area rate boundary
**If multiple rows:** PID overlaps multiple area rate zones (only largest kept in next step)

**Check for NULL AREARATE_CODE (causes removal in Step 1):**
```sql
SELECT * FROM SAP_ADM_TAX_DESIGNATION
WHERE PID = 41019084 AND AREARATE_CODE IS NULL;
```

---

### **CHECKPOINT 2: Check AR_*_pid_SAP Tables (After Step 1)**

**Step 1 filters:**
- Only keeps row with largest `shape_area` per PID
- Removes rows where `AREARATE_CODE IS NULL OR LIKE ''`

```sql
-- Tax Designation
SELECT * FROM AR_taxdes_pid_SAP WHERE PID = 41019084;

-- BID
SELECT * FROM AR_bid_pid_SAP WHERE PID = 41019084;

-- Transit
SELECT * FROM AR_TRANSIT_pid_SAP WHERE PID = 41019084;

-- Active Transit
SELECT * FROM AR_active_trans_pid_SAP WHERE PID = 41019084;

-- Fire Protection
SELECT * FROM AR_FIRE_PROTECTION_pid_SAP WHERE PID = 41019084;

-- Commercial Facilities
SELECT * FROM AR_ComFacServ_pid_SAP WHERE PID = 41019084;

-- Commercial
SELECT * FROM AR_commercial_pid_SAP WHERE PID = 41019084;

-- Stormwater
SELECT * FROM AR_stormwater_pid_SAP WHERE PID = 41019084;

-- Private Road
SELECT * FROM AR_Priv_Road_pid_SAP WHERE PID = 41019084;
```

**Expected Result:** 1 row (or 0 if filtered out)
**If 0 rows and SAP had multiple rows:** Only largest overlap kept; check ranking:

```sql
-- See all overlaps ranked by size
SELECT t1.pid, t1.AREARATE_CODE, t1.shape_area,
       ROW_NUMBER() OVER (PARTITION BY t1.pid ORDER BY t1.shape_area DESC) AS rn
FROM SAP_ADM_TAX_DESIGNATION t1
WHERE t1.pid = 41019084;
```

**If 0 rows and SAP had NULL AREARATE_CODE:** Filtered out by NULL check

---

### **CHECKPOINT 3: Check PID→AAN Lookup (LINNS_PIDAANTAX)**

**Step 2 requires** a match in `LINNS_PIDAANTAX` to get the AAN (Account Number).

```sql
-- Check if PID has an AAN mapping
SELECT * FROM LINNS_PIDAANTAX WHERE pid = 41019084;
```

**Expected Result:** 1+ rows
**If 0 rows:** **CRITICAL FAILURE POINT** - PID has no AAN mapping, will be filtered out in Step 2
**If AAN IS NULL or blank:** Will be deleted in Step 2

---

### **CHECKPOINT 4: Check AR_*_AAN_SAP Tables (After Step 2)**

**Step 2 joins AR_*_pid_SAP with LINNS_PIDAANTAX to get AANs.**

```sql
-- Tax Designation
SELECT * FROM AR_taxdes_AAN_SAP WHERE PID = 41019084;

-- BID
SELECT * FROM AR_bid_AAN_SAP WHERE PID = 41019084;

-- Transit
SELECT * FROM AR_TRANSIT_AAN_SAP WHERE PID = 41019084;

-- Active Transit
SELECT * FROM AR_active_trans_AAN_SAP WHERE PID = 41019084;

-- Fire Protection
SELECT * FROM AR_FIRE_PROTECTION_AAN_SAP WHERE PID = 41019084;

-- Commercial Facilities
SELECT * FROM AR_ComFacServ_AAN_SAP WHERE PID = 41019084;

-- Commercial
SELECT * FROM AR_commercial_AAN_SAP WHERE PID = 41019084;

-- Stormwater
SELECT * FROM AR_stormwater_AAN_SAP WHERE PID = 41019084;

-- Private Road
SELECT * FROM AR_Priv_Road_AAN_SAP WHERE PID = 41019084;
```

**Expected Result:** 1+ rows
**If 0 rows:** PID not in `LINNS_PIDAANTAX` or AAN was NULL/blank

---

### **CHECKPOINT 5: Check if PID is a Condo Common Parcel**

**Step 3 identifies** condo common parcels using `LINNS_PIDRELATE`.

```sql
-- Check if PID is a condo common parcel
SELECT * FROM linns_pidrelate
WHERE pid = 41019084 AND RELNAME = 'CONDO COMMON PARCEL';
```

**Expected Result:** 0 rows (regular parcel) or 1+ rows (condo common parcel)
**If 1+ rows:** PID is a condo common parcel; check condo processing tables

---

### **CHECKPOINT 6: Check AR_*_CONDO_in_SAP Tables (Step 3 Output)**

**Only relevant if PID is a condo common parcel.**

```sql
-- Tax Designation
SELECT * FROM AR_taxdes_CONDO_in_SAP WHERE PID = 41019084;

-- BID
SELECT * FROM AR_bid_CONDO_in_SAP WHERE PID = 41019084;

-- Transit
SELECT * FROM AR_TRANSIT_CONDO_in_SAP WHERE PID = 41019084;

-- (etc. for other area rate types)
```

**Expected Result:** Rows showing PID (common parcel) + PIDRELATE (unit PIDs)

---

### **CHECKPOINT 7: Check AR_*_CONDO_AAN_SAP Tables (Step 4 Output)**

**Step 4 gets AANs for condo UNITS** (using PIDRELATE from Step 3).

```sql
-- Tax Designation (shows condo unit AANs)
SELECT * FROM AR_taxdes_CONDO_AAN_SAP WHERE pid = 41019084;

-- Or check by unit PID if you know it
SELECT * FROM AR_taxdes_CONDO_AAN_SAP WHERE PIDRELATE = 41019084;

-- BID
SELECT * FROM AR_bid_CONDO_AAN_SAP WHERE pid = 41019084;

-- Transit
SELECT * FROM AR_TRANSIT_CONDO_AAN_SAP WHERE pid = 41019084;

-- (etc. for other area rate types)
```

**Expected Result:** Rows with unit PIDs and their AANs
**If 0 rows:** Condo units don't have AAN mappings in `LINNS_PIDAANTAX`

---

### **CHECKPOINT 8: Check AR_*_FINAL_SAP Tables (After Step 5)**

**Step 5 combines** non-condo records (from Step 2) and condo records (from Step 4).

```sql
-- Tax Designation
SELECT * FROM AR_taxdes_FINAL_SAP WHERE PID = 41019084;

-- BID
SELECT * FROM AR_bid_FINAL_SAP WHERE PID = 41019084;

-- Transit
SELECT * FROM AR_TRANSIT_FINAL_SAP WHERE PID = 41019084;

-- Active Transit
SELECT * FROM AR_active_trans_FINAL_SAP WHERE PID = 41019084;

-- Fire Protection
SELECT * FROM AR_FIRE_PROTECTION_FINAL_SAP WHERE PID = 41019084;

-- Commercial Facilities
SELECT * FROM AR_ComFacServ_FINAL_SAP WHERE PID = 41019084;

-- Commercial
SELECT * FROM AR_commercial_FINAL_SAP WHERE PID = 41019084;

-- Stormwater
SELECT * FROM AR_stormwater_FINAL_SAP WHERE PID = 41019084;

-- Private Road
SELECT * FROM AR_Priv_Road_FINAL_SAP WHERE PID = 41019084;
```

**Expected Result:** 1+ rows (may appear in multiple area rate types)
**If 0 rows:** Filtered out in validation step (NULL/blank ACCTNO or ARCODE)

---

### **CHECKPOINT 9: Check Final Aggregate Table**

**All *_FINAL_SAP tables are consolidated** into `Area_Rates_PID_AAN`.

```sql
-- Check if PID made it to the final aggregate table
SELECT * FROM Area_Rates_PID_AAN WHERE PID = 41019084;

-- See all area rate codes for this PID
SELECT PID, AAN as ACCTNO, AREARATE_CODE, TAXYEAR, UPDATED
FROM Area_Rates_PID_AAN
WHERE PID = 41019084
ORDER BY AREARATE_CODE;
```

**Expected Result:** 1+ rows (one per area rate type)
**If 0 rows:** Check if PID exists in any *_FINAL_SAP table

---

### **CHECKPOINT 10: Check for Explicit Removals**

**Some PIDs are explicitly removed** in `remove_pids.sql`.

```sql
-- Check if PID was explicitly removed (M060 area rate code)
-- This query shows what WOULD have been removed
SELECT * FROM Area_Rates_PID_AAN
WHERE PID = 41019084 AND AREARATE_CODE LIKE 'M060';
```

**Expected Result:** 0 rows (not removed) or historical data if removed
**If removed:** Check `SQL/remove_pids.sql` for the removal logic

---

## **COMMON FAILURE POINTS**

| Checkpoint | Table | Failure Reason | Fix |
|-----------|-------|----------------|-----|
| **1** | `SAP_*` | PID doesn't intersect area rate boundary | Check geometry overlap in GIS |
| **1** | `SAP_*` | `AREARATE_CODE IS NULL` | Check area rate boundary feature has valid codes |
| **2** | `AR_*_pid_SAP` | Multiple overlaps, not largest | Expected behavior; largest overlap wins |
| **2** | `AR_*_pid_SAP` | NULL/blank ARCODE | Check `SAP_*` table for NULL values |
| **3** | `AR_*_AAN_SAP` | **PID not in LINNS_PIDAANTAX** | **Most common failure** - PID lacks AAN mapping |
| **3** | `AR_*_AAN_SAP` | AAN is NULL or blank | Check `LINNS_PIDAANTAX` data quality |
| **7** | `AR_*_CONDO_AAN_SAP` | Condo units lack AAN | Check unit PIDs in `LINNS_PIDAANTAX` |
| **8** | `AR_*_FINAL_SAP` | NULL validation failure | Check ACCTNO/ARCODE for NULL/blank |
| **10** | Final | Explicit removal (M060) | Check `remove_pids.sql` |

---

## **FULL DIAGNOSTIC QUERY**

Run this to see PID status across all key tables at once:

```sql
-- Comprehensive PID lookup
DECLARE @pid INT = 41019084;

-- Source parcel
SELECT 'LND_parcel_polygon' AS TableName, COUNT(*) AS RecordCount
FROM LND_parcel_polygon WHERE pid = @pid

UNION ALL

-- SAP tables (Spatial Analysis Products)
SELECT 'SAP_ADM_TAX_DESIGNATION', COUNT(*) FROM SAP_ADM_TAX_DESIGNATION WHERE PID = @pid
UNION ALL
SELECT 'SAP_bid', COUNT(*) FROM SAP_bid WHERE PID = @pid
UNION ALL
SELECT 'SAP_TRANSIT', COUNT(*) FROM SAP_TRANSIT WHERE PID = @pid
UNION ALL
SELECT 'SAP_FIRE_PROTECTION', COUNT(*) FROM SAP_FIRE_PROTECTION WHERE PID = @pid
UNION ALL
SELECT 'SAP_ComFacServ', COUNT(*) FROM SAP_ComFacServ WHERE PID = @pid

UNION ALL

-- PID tables (Step 1)
SELECT 'AR_taxdes_pid_SAP', COUNT(*) FROM AR_taxdes_pid_SAP WHERE PID = @pid
UNION ALL
SELECT 'AR_bid_pid_SAP', COUNT(*) FROM AR_bid_pid_SAP WHERE PID = @pid
UNION ALL
SELECT 'AR_TRANSIT_pid_SAP', COUNT(*) FROM AR_TRANSIT_pid_SAP WHERE PID = @pid
UNION ALL
SELECT 'AR_FIRE_PROTECTION_pid_SAP', COUNT(*) FROM AR_FIRE_PROTECTION_pid_SAP WHERE PID = @pid
UNION ALL
SELECT 'AR_ComFacServ_pid_SAP', COUNT(*) FROM AR_ComFacServ_pid_SAP WHERE PID = @pid

UNION ALL

-- AAN tables (Step 2)
SELECT 'AR_taxdes_AAN_SAP', COUNT(*) FROM AR_taxdes_AAN_SAP WHERE PID = @pid
UNION ALL
SELECT 'AR_bid_AAN_SAP', COUNT(*) FROM AR_bid_AAN_SAP WHERE PID = @pid
UNION ALL
SELECT 'AR_TRANSIT_AAN_SAP', COUNT(*) FROM AR_TRANSIT_AAN_SAP WHERE PID = @pid
UNION ALL
SELECT 'AR_FIRE_PROTECTION_AAN_SAP', COUNT(*) FROM AR_FIRE_PROTECTION_AAN_SAP WHERE PID = @pid
UNION ALL
SELECT 'AR_ComFacServ_AAN_SAP', COUNT(*) FROM AR_ComFacServ_AAN_SAP WHERE PID = @pid

UNION ALL

-- FINAL tables (Step 5)
SELECT 'AR_taxdes_FINAL_SAP', COUNT(*) FROM AR_taxdes_FINAL_SAP WHERE PID = @pid
UNION ALL
SELECT 'AR_bid_FINAL_SAP', COUNT(*) FROM AR_bid_FINAL_SAP WHERE PID = @pid
UNION ALL
SELECT 'AR_TRANSIT_FINAL_SAP', COUNT(*) FROM AR_TRANSIT_FINAL_SAP WHERE PID = @pid
UNION ALL
SELECT 'AR_FIRE_PROTECTION_FINAL_SAP', COUNT(*) FROM AR_FIRE_PROTECTION_FINAL_SAP WHERE PID = @pid
UNION ALL
SELECT 'AR_ComFacServ_FINAL_SAP', COUNT(*) FROM AR_ComFacServ_FINAL_SAP WHERE PID = @pid

UNION ALL

-- Final aggregate table
SELECT 'Area_Rates_PID_AAN', COUNT(*) FROM Area_Rates_PID_AAN WHERE PID = @pid

UNION ALL

-- Lookup tables
SELECT 'LINNS_PIDAANTAX', COUNT(*) FROM LINNS_PIDAANTAX WHERE pid = @pid
UNION ALL
SELECT 'LINNS_PIDRELATE (condo)', COUNT(*) FROM linns_pidrelate
WHERE pid = @pid AND RELNAME = 'CONDO COMMON PARCEL'

ORDER BY TableName;
```

---

## **EXAMPLE: Tracking PID 41019084**

```sql
-- 1. Verify source
SELECT pid FROM LND_parcel_polygon WHERE pid = 41019084;
-- Result: 1 row ✓

-- 2. Check spatial intersection (Tax Designation example)
SELECT * FROM SAP_ADM_TAX_DESIGNATION WHERE PID = 41019084;
-- Result: Shows overlap with tax designation zones

-- 3. Check if it survived Step 1 filtering
SELECT * FROM AR_taxdes_pid_SAP WHERE PID = 41019084;
-- Result: 1 row with PID, ARCODE, AREA ✓

-- 4. Check PID→AAN lookup
SELECT * FROM LINNS_PIDAANTAX WHERE pid = 41019084;
-- Result: ??? (This is where you might find the gap)

-- 5. Check if it has an AAN assigned
SELECT * FROM AR_taxdes_AAN_SAP WHERE PID = 41019084;
-- Result: 0 rows = PID NOT IN LINNS_PIDAANTAX

-- 6. Check final table
SELECT * FROM AR_taxdes_FINAL_SAP WHERE PID = 41019084;
-- Result: 0 rows (filtered out in Step 2 due to missing AAN)

-- 7. Check aggregate
SELECT * FROM Area_Rates_PID_AAN WHERE PID = 41019084;
-- Result: 0 rows (never made it past Step 2)
```

---

## **QUICK REFERENCE: SQL File Locations**

```
SQL/
├── taxdes/
│   ├── ar_taxdes1_pid_SAP.sql        (Step 1: PID → ARCODE)
│   ├── ar_taxdes2_AAN_SAP.sql        (Step 2: PID → AAN)
│   ├── ar_taxdes3_CONDO_in_SAP.sql   (Step 3: Find condos)
│   ├── ar_taxdes4_CONDO_SAP.sql      (Step 4: Condo AANs)
│   ├── ar_taxdes5_final_SAP.sql      (Step 5: Combine)
│   └── ar_taxdes6_clean_SAP.sql      (Step 6: Cleanup)
├── bid/                              (Same structure)
├── transit/                          (Same structure)
├── fire/                             (Same structure)
├── ComFacServ/                       (Same structure)
├── commercial/                       (Same structure)
├── stormwater/                       (Same structure)
├── Priv_Road/                        (Same structure)
├── active_trans/                     (Same structure)
└── remove_pids.sql                   (Explicit removals)
```

---

## **KEY TAKEAWAYS**

1. **Most common failure point:** PID not in `LINNS_PIDAANTAX` (Step 2)
2. **Spatial failures:** PID doesn't intersect area rate boundary (Step 1)
3. **NULL/blank failures:** AREARATE_CODE, AAN, or ARCODE is NULL/blank
4. **Condo complexity:** Common parcels vs. unit PIDs require different handling
5. **Explicit removals:** Check `remove_pids.sql` for hardcoded exclusions

---

## **NEXT STEPS FOR DEBUGGING**

1. Start at Checkpoint 0 - verify PID exists
2. Work through checkpoints sequentially
3. When you find 0 rows, **that's where the PID got filtered out**
4. Check the "COMMON FAILURE POINTS" table for the reason
5. Review the SQL file for that step to understand the filter logic

---

**Created:** 2026-02-10
**Purpose:** Debug PID filtering in Area Rates processing pipeline
