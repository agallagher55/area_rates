-- ============================================================================
-- Local Area Transit Rate - Pre-Prod (QA) Differences Report
--
-- Requested by: Vicki Robertson (Director, Revenue) - email 2026-08-15,
-- "Local Area Transit Rate - Report from pre-prod". Revenue is seeing
-- differences "both ways" for the local area transit rate and wants a
-- listing of what changed so they can work out what's a real route change
-- vs. a measurement artifact (see known_issues.md #1 and #2 for the two
-- documented candidates: the provincial PID/AAN timing gap, and overlapping
-- Area Rate boundary polygons dropping/reassigning a code).
--
-- This script does NOT attempt to classify each row's cause - it only lists
-- the accounts whose local transit rate code differs. Cross-reference
-- suspicious rows against known_issues.md, or walk them through
-- PID_TRACKING_CHEATSHEET.md / track_pid_41019084.sql, to see which bucket
-- they fall into.
--
-- Data lineage (see PID_TRACKING_CHEATSHEET.md):
--   NEW = SDEADM.AR_TRANSIT_FINAL_SAP
--         Rebuilt by SQL/transit/Run_Transit.sql from this pre-prod (QA)
--         GIS call's overlay output (SAP_TRANSIT -> AR_TRANSIT_pid_SAP ->
--         AR_TRANSIT_AAN_SAP / AR_TRANSIT_CONDO_AAN_SAP -> AR_TRANSIT_FINAL_SAP).
--         This is the pre-prod run's result.
--   OLD = SDEADM.Area_Rates_PID_AAN, filtered to AREARATE_CODE = 'M060'
--         Area_Rates_PID_AAN is the aggregate table alter_final_tables.py
--         loads from every *_FINAL_SAP table (PID, AAN, AREARATE_CODE) - it
--         doesn't tag which area rate type a row came from, so this report
--         filters it to M060, the Local Area Transit Rate code (see
--         AREA_RATE_CODES.md). Don't confuse with M070 (Regional Transit,
--         deprecated) - a different code/boundary entirely.
--
--   !! ASSUMPTION TO VERIFY BEFORE TRUSTING THIS REPORT !!
--   Area_Rates_PID_AAN only holds the prior committed transit state if
--   alter_final_tables.py has NOT been re-run since this pre-prod GIS call
--   finished. If it HAS already been re-run, Area_Rates_PID_AAN reflects the
--   NEW values too and this report will show close to nothing. The row-count
--   sanity check at the bottom flags that case - if New_Row_Count and
--   Old_Row_Count come back (nearly) identical, that's likely what happened.
-- ============================================================================

PRINT '============================================================================';
PRINT 'Local Area Transit Rate differences: pre-prod (QA) run vs. last committed state';
PRINT '============================================================================';

WITH New_Transit AS (
    SELECT ACCTNO, PID, ARCODE
    FROM SDEADM.AR_TRANSIT_FINAL_SAP
),
Old_Transit AS (
    SELECT AAN AS ACCTNO, PID, AREARATE_CODE AS ARCODE
    FROM SDEADM.Area_Rates_PID_AAN
    WHERE AREARATE_CODE = 'M060'
)
SELECT
    COALESCE(n.ACCTNO, o.ACCTNO) AS ACCTNO,
    o.PID          AS Old_PID,
    n.PID          AS New_PID,
    o.ARCODE       AS Old_ARCODE,
    n.ARCODE       AS New_ARCODE,
    CASE
        WHEN o.ACCTNO IS NULL THEN 'ADDED - new to local transit rate'
        WHEN n.ACCTNO IS NULL THEN 'REMOVED - dropped from local transit rate'
        WHEN o.PID <> n.PID    THEN 'CHANGED - code and PID differ (parcel/condo history changed - check PID)'
        ELSE 'CHANGED - same PID, different code'
    END AS Change_Type
FROM New_Transit n
FULL OUTER JOIN Old_Transit o
    ON n.ACCTNO = o.ACCTNO
WHERE o.ACCTNO IS NULL        -- added
   OR n.ACCTNO IS NULL        -- removed
   OR o.ARCODE <> n.ARCODE    -- changed code
ORDER BY Change_Type, ACCTNO;

PRINT '';
PRINT '============================================================================';
PRINT 'Sanity check - if these two counts are (nearly) equal, Area_Rates_PID_AAN';
PRINT 'may already reflect the NEW run (alter_final_tables.py already re-ran),';
PRINT 'which would make the diff above misleadingly small.';
PRINT '============================================================================';

SELECT
    (SELECT COUNT(*) FROM SDEADM.AR_TRANSIT_FINAL_SAP) AS New_Row_Count,
    (SELECT COUNT(*)
     FROM SDEADM.Area_Rates_PID_AAN
     WHERE AREARATE_CODE = 'M060') AS Old_Row_Count;
