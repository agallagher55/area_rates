-- ============================================================================
-- PID TRACKING SCRIPT: 41019084
-- This script walks through all checkpoints to find where the PID gets dropped
-- Run each section sequentially and note where you get 0 rows
-- ============================================================================

PRINT '================================================================';
PRINT 'TRACKING PID: 41019084';
PRINT 'Timestamp: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '================================================================';
PRINT '';

-- ============================================================================
-- CHECKPOINT 0: Source Data
-- ============================================================================
PRINT '------------------------------------------------------------';
PRINT 'CHECKPOINT 0: Verify PID exists in source parcel layer';
PRINT '------------------------------------------------------------';

SELECT 'LND_parcel_polygon' AS Source, pid, SHAPE.STArea() as area
FROM LND_parcel_polygon
WHERE pid = 41019084;

PRINT '';
PRINT '>> If 0 rows: PID does not exist in source data';
PRINT '';

-- ============================================================================
-- CHECKPOINT 1: SAP Tables (Spatial Analysis Products)
-- ============================================================================
PRINT '------------------------------------------------------------';
PRINT 'CHECKPOINT 1: SAP Tables (After GIS Identity/Frequency Analysis)';
PRINT '------------------------------------------------------------';

-- Tax Designation
PRINT '--- Tax Designation (SAP_ADM_TAX_DESIGNATION) ---';
SELECT 'SAP_ADM_TAX_DESIGNATION' AS TableName, PID, AREARATE_CODE, shape_area
FROM SAP_ADM_TAX_DESIGNATION
WHERE PID = 41019084
ORDER BY shape_area DESC;

-- BID
PRINT '--- BID (SAP_bid) ---';
SELECT 'SAP_bid' AS TableName, PID, AREARATE_CODE, shape_area
FROM SAP_bid
WHERE PID = 41019084
ORDER BY shape_area DESC;

-- Transit
PRINT '--- Transit (SAP_TRANSIT) ---';
SELECT 'SAP_TRANSIT' AS TableName, PID, AREARATE_CODE, shape_area
FROM SAP_TRANSIT
WHERE PID = 41019084
ORDER BY shape_area DESC;

-- Active Transit
PRINT '--- Active Transit (SAP_active_trans) ---';
SELECT 'SAP_active_trans' AS TableName, PID, AREARATE_CODE, shape_area
FROM SAP_active_trans
WHERE PID = 41019084
ORDER BY shape_area DESC;

-- Fire Protection
PRINT '--- Fire Protection (SAP_FIRE_PROTECTION) ---';
SELECT 'SAP_FIRE_PROTECTION' AS TableName, PID, AREARATE_CODE, shape_area
FROM SAP_FIRE_PROTECTION
WHERE PID = 41019084
ORDER BY shape_area DESC;

-- Commercial Facilities
PRINT '--- Commercial Facilities (SAP_ComFacServ) ---';
SELECT 'SAP_ComFacServ' AS TableName, PID, AREARATE_CODE, shape_area
FROM SAP_ComFacServ
WHERE PID = 41019084
ORDER BY shape_area DESC;

-- Commercial
PRINT '--- Commercial (SAP_commercial) ---';
SELECT 'SAP_commercial' AS TableName, PID, AREARATE_CODE, shape_area
FROM SAP_commercial
WHERE PID = 41019084
ORDER BY shape_area DESC;

-- Stormwater
PRINT '--- Stormwater (SAP_stormwater) ---';
SELECT 'SAP_stormwater' AS TableName, PID, AREARATE_CODE, shape_area
FROM SAP_stormwater
WHERE PID = 41019084
ORDER BY shape_area DESC;

-- Private Road
PRINT '--- Private Road (SAP_Priv_Road) ---';
SELECT 'SAP_Priv_Road' AS TableName, PID, AREARATE_CODE, shape_area
FROM SAP_Priv_Road
WHERE PID = 41019084
ORDER BY shape_area DESC;

PRINT '';
PRINT '>> If 0 rows for a type: PID does not spatially intersect that area rate boundary';
PRINT '>> If multiple rows: PID overlaps multiple zones (only largest kept in next step)';
PRINT '>> If AREARATE_CODE IS NULL: Will be filtered out in Step 1';
PRINT '';

-- ============================================================================
-- CHECKPOINT 2: AR_*_pid_SAP Tables (After Step 1 - PID → ARCODE Selection)
-- ============================================================================
PRINT '------------------------------------------------------------';
PRINT 'CHECKPOINT 2: AR_*_pid_SAP Tables (Step 1: PID → ARCODE)';
PRINT 'Filters: Only largest overlap, AREARATE_CODE NOT NULL';
PRINT '------------------------------------------------------------';

-- Tax Designation
PRINT '--- Tax Designation (AR_taxdes_pid_SAP) ---';
SELECT 'AR_taxdes_pid_SAP' AS TableName, PID, ARCODE, AREA
FROM AR_taxdes_pid_SAP
WHERE PID = 41019084;

-- BID
PRINT '--- BID (AR_bid_pid_SAP) ---';
SELECT 'AR_bid_pid_SAP' AS TableName, PID, ARCODE, AREA
FROM AR_bid_pid_SAP
WHERE PID = 41019084;

-- Transit
PRINT '--- Transit (AR_TRANSIT_pid_SAP) ---';
SELECT 'AR_TRANSIT_pid_SAP' AS TableName, PID, ARCODE, AREA
FROM AR_TRANSIT_pid_SAP
WHERE PID = 41019084;

-- Active Transit
PRINT '--- Active Transit (AR_active_trans_pid_SAP) ---';
SELECT 'AR_active_trans_pid_SAP' AS TableName, PID, ARCODE, AREA
FROM AR_active_trans_pid_SAP
WHERE PID = 41019084;

-- Fire Protection
PRINT '--- Fire Protection (AR_FIRE_PROTECTION_pid_SAP) ---';
SELECT 'AR_FIRE_PROTECTION_pid_SAP' AS TableName, PID, ARCODE, AREA
FROM AR_FIRE_PROTECTION_pid_SAP
WHERE PID = 41019084;

-- Commercial Facilities
PRINT '--- Commercial Facilities (AR_ComFacServ_pid_SAP) ---';
SELECT 'AR_ComFacServ_pid_SAP' AS TableName, PID, ARCODE, AREA
FROM AR_ComFacServ_pid_SAP
WHERE PID = 41019084;

-- Commercial
PRINT '--- Commercial (AR_commercial_pid_SAP) ---';
SELECT 'AR_commercial_pid_SAP' AS TableName, PID, ARCODE, AREA
FROM AR_commercial_pid_SAP
WHERE PID = 41019084;

-- Stormwater
PRINT '--- Stormwater (AR_stormwater_pid_SAP) ---';
SELECT 'AR_stormwater_pid_SAP' AS TableName, PID, ARCODE, AREA
FROM AR_stormwater_pid_SAP
WHERE PID = 41019084;

-- Private Road
PRINT '--- Private Road (AR_Priv_Road_pid_SAP) ---';
SELECT 'AR_Priv_Road_pid_SAP' AS TableName, PID, ARCODE, AREA
FROM AR_Priv_Road_pid_SAP
WHERE PID = 41019084;

PRINT '';
PRINT '>> If 0 rows but SAP had data: Filtered by NULL AREARATE_CODE or not largest overlap';
PRINT '';

-- ============================================================================
-- CHECKPOINT 3: LINNS_PIDAANTAX Lookup (CRITICAL POINT)
-- ============================================================================
PRINT '------------------------------------------------------------';
PRINT 'CHECKPOINT 3: PID→AAN Lookup Table (LINNS_PIDAANTAX)';
PRINT '***** MOST COMMON FAILURE POINT *****';
PRINT '------------------------------------------------------------';

SELECT 'LINNS_PIDAANTAX' AS TableName, pid, AAN, TAXNO
FROM LINNS_PIDAANTAX
WHERE pid = 41019084;

PRINT '';
PRINT '>> If 0 rows: *** PID NOT IN LOOKUP TABLE - WILL BE DROPPED IN STEP 2 ***';
PRINT '>> If AAN IS NULL or blank: Will be filtered out in Step 2';
PRINT '';

-- ============================================================================
-- CHECKPOINT 4: AR_*_AAN_SAP Tables (After Step 2 - PID → AAN Mapping)
-- ============================================================================
PRINT '------------------------------------------------------------';
PRINT 'CHECKPOINT 4: AR_*_AAN_SAP Tables (Step 2: PID → AAN Join)';
PRINT 'Requires: Match in LINNS_PIDAANTAX with non-NULL AAN';
PRINT '------------------------------------------------------------';

-- Tax Designation
PRINT '--- Tax Designation (AR_taxdes_AAN_SAP) ---';
SELECT 'AR_taxdes_AAN_SAP' AS TableName, PID, ACCTNO, arcode
FROM AR_taxdes_AAN_SAP
WHERE PID = 41019084;

-- BID
PRINT '--- BID (AR_bid_AAN_SAP) ---';
SELECT 'AR_bid_AAN_SAP' AS TableName, PID, ACCTNO, arcode
FROM AR_bid_AAN_SAP
WHERE PID = 41019084;

-- Transit
PRINT '--- Transit (AR_TRANSIT_AAN_SAP) ---';
SELECT 'AR_TRANSIT_AAN_SAP' AS TableName, PID, ACCTNO, arcode
FROM AR_TRANSIT_AAN_SAP
WHERE PID = 41019084;

-- Active Transit
PRINT '--- Active Transit (AR_active_trans_AAN_SAP) ---';
SELECT 'AR_active_trans_AAN_SAP' AS TableName, PID, ACCTNO, arcode
FROM AR_active_trans_AAN_SAP
WHERE PID = 41019084;

-- Fire Protection
PRINT '--- Fire Protection (AR_FIRE_PROTECTION_AAN_SAP) ---';
SELECT 'AR_FIRE_PROTECTION_AAN_SAP' AS TableName, PID, ACCTNO, arcode
FROM AR_FIRE_PROTECTION_AAN_SAP
WHERE PID = 41019084;

-- Commercial Facilities
PRINT '--- Commercial Facilities (AR_ComFacServ_AAN_SAP) ---';
SELECT 'AR_ComFacServ_AAN_SAP' AS TableName, PID, ACCTNO, arcode
FROM AR_ComFacServ_AAN_SAP
WHERE PID = 41019084;

-- Commercial
PRINT '--- Commercial (AR_commercial_AAN_SAP) ---';
SELECT 'AR_commercial_AAN_SAP' AS TableName, PID, ACCTNO, arcode
FROM AR_commercial_AAN_SAP
WHERE PID = 41019084;

-- Stormwater
PRINT '--- Stormwater (AR_stormwater_AAN_SAP) ---';
SELECT 'AR_stormwater_AAN_SAP' AS TableName, PID, ACCTNO, arcode
FROM AR_stormwater_AAN_SAP
WHERE PID = 41019084;

-- Private Road
PRINT '--- Private Road (AR_Priv_Road_AAN_SAP) ---';
SELECT 'AR_Priv_Road_AAN_SAP' AS TableName, PID, ACCTNO, arcode
FROM AR_Priv_Road_AAN_SAP
WHERE PID = 41019084;

PRINT '';
PRINT '>> If 0 rows: PID not in LINNS_PIDAANTAX or AAN was NULL/blank';
PRINT '';

-- ============================================================================
-- CHECKPOINT 5: Condo Check
-- ============================================================================
PRINT '------------------------------------------------------------';
PRINT 'CHECKPOINT 5: Condo Common Parcel Check (LINNS_PIDRELATE)';
PRINT '------------------------------------------------------------';

SELECT 'LINNS_PIDRELATE' AS TableName, PID, PIDRELATE, RELNAME
FROM linns_pidrelate
WHERE pid = 41019084 AND RELNAME = 'CONDO COMMON PARCEL';

PRINT '';
PRINT '>> If 0 rows: PID is a regular parcel (non-condo)';
PRINT '>> If 1+ rows: PID is a condo common parcel - check condo tables below';
PRINT '';

-- ============================================================================
-- CHECKPOINT 6: AR_*_CONDO_in_SAP Tables (Step 3 - Condo Identification)
-- ============================================================================
PRINT '------------------------------------------------------------';
PRINT 'CHECKPOINT 6: AR_*_CONDO_in_SAP Tables (Step 3: Condo ID)';
PRINT 'Only relevant if PID is a condo common parcel';
PRINT '------------------------------------------------------------';

-- Tax Designation
PRINT '--- Tax Designation (AR_taxdes_CONDO_in_SAP) ---';
SELECT 'AR_taxdes_CONDO_in_SAP' AS TableName, PID, PIDRELATE, RELNAME, arcode
FROM AR_taxdes_CONDO_in_SAP
WHERE PID = 41019084;

-- BID
PRINT '--- BID (AR_bid_CONDO_in_SAP) ---';
SELECT 'AR_bid_CONDO_in_SAP' AS TableName, PID, PIDRELATE, RELNAME, arcode
FROM AR_bid_CONDO_in_SAP
WHERE PID = 41019084;

-- Transit
PRINT '--- Transit (AR_TRANSIT_CONDO_in_SAP) ---';
SELECT 'AR_TRANSIT_CONDO_in_SAP' AS TableName, PID, PIDRELATE, RELNAME, arcode
FROM AR_TRANSIT_CONDO_in_SAP
WHERE PID = 41019084;

PRINT '';

-- ============================================================================
-- CHECKPOINT 7: AR_*_CONDO_AAN_SAP Tables (Step 4 - Condo Unit AANs)
-- ============================================================================
PRINT '------------------------------------------------------------';
PRINT 'CHECKPOINT 7: AR_*_CONDO_AAN_SAP Tables (Step 4: Condo AANs)';
PRINT 'Shows condo UNIT AANs linked to common parcel';
PRINT '------------------------------------------------------------';

-- Tax Designation
PRINT '--- Tax Designation (AR_taxdes_CONDO_AAN_SAP) ---';
SELECT 'AR_taxdes_CONDO_AAN_SAP' AS TableName, ACCTNO, PIDRELATE as Unit_PID, pid as Common_PID, arcode
FROM AR_taxdes_CONDO_AAN_SAP
WHERE pid = 41019084;

-- BID
PRINT '--- BID (AR_bid_CONDO_AAN_SAP) ---';
SELECT 'AR_bid_CONDO_AAN_SAP' AS TableName, ACCTNO, PIDRELATE as Unit_PID, pid as Common_PID, arcode
FROM AR_bid_CONDO_AAN_SAP
WHERE pid = 41019084;

-- Transit
PRINT '--- Transit (AR_TRANSIT_CONDO_AAN_SAP) ---';
SELECT 'AR_TRANSIT_CONDO_AAN_SAP' AS TableName, ACCTNO, PIDRELATE as Unit_PID, pid as Common_PID, arcode
FROM AR_TRANSIT_CONDO_AAN_SAP
WHERE pid = 41019084;

PRINT '';
PRINT '>> If 0 rows but CONDO_in shows data: Condo units lack AAN in LINNS_PIDAANTAX';
PRINT '';

-- ============================================================================
-- CHECKPOINT 8: AR_*_FINAL_SAP Tables (Step 5 - Combined Output)
-- ============================================================================
PRINT '------------------------------------------------------------';
PRINT 'CHECKPOINT 8: AR_*_FINAL_SAP Tables (Step 5: Combined)';
PRINT 'Combines non-condo (Step 2) + condo (Step 4) records';
PRINT '------------------------------------------------------------';

-- Tax Designation
PRINT '--- Tax Designation (AR_taxdes_FINAL_SAP) ---';
SELECT 'AR_taxdes_FINAL_SAP' AS TableName, PID, ACCTNO, ARCODE
FROM AR_taxdes_FINAL_SAP
WHERE PID = 41019084;

-- BID
PRINT '--- BID (AR_bid_FINAL_SAP) ---';
SELECT 'AR_bid_FINAL_SAP' AS TableName, PID, ACCTNO, ARCODE
FROM AR_bid_FINAL_SAP
WHERE PID = 41019084;

-- Transit
PRINT '--- Transit (AR_TRANSIT_FINAL_SAP) ---';
SELECT 'AR_TRANSIT_FINAL_SAP' AS TableName, PID, ACCTNO, ARCODE
FROM AR_TRANSIT_FINAL_SAP
WHERE PID = 41019084;

-- Active Transit
PRINT '--- Active Transit (AR_active_trans_FINAL_SAP) ---';
SELECT 'AR_active_trans_FINAL_SAP' AS TableName, PID, ACCTNO, ARCODE
FROM AR_active_trans_FINAL_SAP
WHERE PID = 41019084;

-- Fire Protection
PRINT '--- Fire Protection (AR_FIRE_PROTECTION_FINAL_SAP) ---';
SELECT 'AR_FIRE_PROTECTION_FINAL_SAP' AS TableName, PID, ACCTNO, ARCODE
FROM AR_FIRE_PROTECTION_FINAL_SAP
WHERE PID = 41019084;

-- Commercial Facilities
PRINT '--- Commercial Facilities (AR_ComFacServ_FINAL_SAP) ---';
SELECT 'AR_ComFacServ_FINAL_SAP' AS TableName, PID, ACCTNO, ARCODE
FROM AR_ComFacServ_FINAL_SAP
WHERE PID = 41019084;

-- Commercial
PRINT '--- Commercial (AR_commercial_FINAL_SAP) ---';
SELECT 'AR_commercial_FINAL_SAP' AS TableName, PID, ACCTNO, ARCODE
FROM AR_commercial_FINAL_SAP
WHERE PID = 41019084;

-- Stormwater
PRINT '--- Stormwater (AR_stormwater_FINAL_SAP) ---';
SELECT 'AR_stormwater_FINAL_SAP' AS TableName, PID, ACCTNO, ARCODE
FROM AR_stormwater_FINAL_SAP
WHERE PID = 41019084;

-- Private Road
PRINT '--- Private Road (AR_Priv_Road_FINAL_SAP) ---';
SELECT 'AR_Priv_Road_FINAL_SAP' AS TableName, PID, ACCTNO, ARCODE
FROM AR_Priv_Road_FINAL_SAP
WHERE PID = 41019084;

PRINT '';
PRINT '>> If 0 rows: Filtered by NULL/blank validation in Step 5';
PRINT '';

-- ============================================================================
-- CHECKPOINT 9: Area_Rates_PID_AAN (Final Aggregate Table)
-- ============================================================================
PRINT '------------------------------------------------------------';
PRINT 'CHECKPOINT 9: Area_Rates_PID_AAN (Final Aggregate Table)';
PRINT 'All *_FINAL_SAP tables consolidated here';
PRINT '------------------------------------------------------------';

SELECT 'Area_Rates_PID_AAN' AS TableName, PID, AAN as ACCTNO, AREARATE_CODE, TAXYEAR, UPDATED
FROM Area_Rates_PID_AAN
WHERE PID = 41019084
ORDER BY AREARATE_CODE;

PRINT '';
PRINT '>> If 0 rows: PID never made it to any *_FINAL_SAP table';
PRINT '';

-- ============================================================================
-- CHECKPOINT 10: Explicit Removals Check
-- ============================================================================
PRINT '------------------------------------------------------------';
PRINT 'CHECKPOINT 10: Explicit Removals (remove_pids.sql)';
PRINT 'Check if PID was removed via M060 area rate code';
PRINT '------------------------------------------------------------';

-- This would show records that match the removal criteria
SELECT 'M060 Removal Check' AS TableName, PID, AAN as ACCTNO, AREARATE_CODE
FROM Area_Rates_PID_AAN
WHERE PID = 41019084 AND AREARATE_CODE LIKE 'M060';

PRINT '';
PRINT '>> If rows shown: PID would be targeted for removal by remove_pids.sql';
PRINT '';

-- ============================================================================
-- SUMMARY COUNTS
-- ============================================================================
PRINT '============================================================';
PRINT 'SUMMARY: Record counts across all tables';
PRINT '============================================================';

SELECT
    'LND_parcel_polygon' AS TableName,
    COUNT(*) AS RecordCount,
    'Source' AS Stage
FROM LND_parcel_polygon WHERE pid = 41019084

UNION ALL
SELECT 'LINNS_PIDAANTAX', COUNT(*), 'Lookup Table'
FROM LINNS_PIDAANTAX WHERE pid = 41019084

UNION ALL
SELECT 'SAP_ADM_TAX_DESIGNATION', COUNT(*), 'Phase 1: GIS'
FROM SAP_ADM_TAX_DESIGNATION WHERE PID = 41019084

UNION ALL
SELECT 'AR_taxdes_pid_SAP', COUNT(*), 'Phase 2: Step 1'
FROM AR_taxdes_pid_SAP WHERE PID = 41019084

UNION ALL
SELECT 'AR_taxdes_AAN_SAP', COUNT(*), 'Phase 2: Step 2'
FROM AR_taxdes_AAN_SAP WHERE PID = 41019084

UNION ALL
SELECT 'AR_taxdes_FINAL_SAP', COUNT(*), 'Phase 2: Step 5'
FROM AR_taxdes_FINAL_SAP WHERE PID = 41019084

UNION ALL
SELECT 'Area_Rates_PID_AAN', COUNT(*), 'Phase 3: Final'
FROM Area_Rates_PID_AAN WHERE PID = 41019084

ORDER BY Stage, TableName;

PRINT '';
PRINT '============================================================';
PRINT 'TRACKING COMPLETE';
PRINT '============================================================';
PRINT '';
PRINT 'INTERPRETATION GUIDE:';
PRINT '- Find the first table where RecordCount = 0';
PRINT '- That is where the PID was filtered out';
PRINT '- Refer to PID_TRACKING_CHEATSHEET.md for failure reasons';
PRINT '';
