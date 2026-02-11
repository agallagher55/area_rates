-- ============================================================================
-- Recently Created PIDs Analysis
-- Purpose: For each AAN, trace the PID history to understand when new PIDs
--          were created (via subdivision/infant parcel) and diagnose why
--          the AAN may have been missed in the area rates analysis.
--
-- Key tables:
--   LINNS_PIDAANTAX  - Current AAN-to-PID mapping
--   LINNS_PIDRELATE  - Parent/child PID relationships
--   LINNS_PIDMSTRS   - PID master record (STARTDATE = PID creation date)
--   LND_parcel_polygon - Parcel fabric (geometry)
-- ============================================================================

-- AANs we're investigating
DECLARE @AANs TABLE (AAN VARCHAR(20));
INSERT INTO @AANs VALUES
    ('05626617'),
    ('05709652'),
    ('06459072'),
    ('08986320'),
    ('08986339'),
    ('09419292'),
    ('09419306'),
    ('09419314'),
    ('09419322'),
    ('09507175'),
    ('09512241'),
    ('09512268'),
    ('09736603'),
    ('10257492');

-- ============================================================================
PRINT '============================================================================';
PRINT 'STEP 1: Current AAN -> PID mapping with PID creation dates';
PRINT '============================================================================';
-- For each AAN, show the current PID and when it was created
-- ============================================================================

SELECT
    pt.AAN,
    pt.PID AS Current_PID,
    pm.STARTDATE AS PID_Created,
    CASE
        WHEN pm.STARTDATE > '2025-08-11' THEN 'Created AFTER Aug 2025 production run'
        ELSE 'Existed at time of Aug 2025 production run'
    END AS Timing_vs_Aug_Run,
    CASE
        WHEN pm.STARTDATE > '2026-01-22' THEN 'Created AFTER Jan 2026 production run'
        ELSE 'Existed at time of Jan 2026 production run'
    END AS Timing_vs_Jan_Run
FROM SDEADM.LINNS_PIDAANTAX pt
LEFT JOIN SDEADM.LINNS_PIDMSTRS pm ON pt.PID = pm.PID
WHERE pt.AAN IN (SELECT AAN FROM @AANs)
ORDER BY pm.STARTDATE DESC, pt.AAN;

-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'STEP 2: PID Relationships - trace parent -> child (subdivision history)';
PRINT '============================================================================';
-- Shows which PIDs are infants/condos and their parent PIDs
-- CRE_DATE = when the relationship was recorded
-- ============================================================================

SELECT
    pt.AAN,
    pt.PID AS Current_PID,
    pm_current.STARTDATE AS Current_PID_Created,
    pr.RELNAME AS Relationship_Type,
    pr.PIDRELATE AS Parent_PID,
    pr.CRE_DATE AS Relationship_Created,
    pm_parent.STARTDATE AS Parent_PID_Created
FROM SDEADM.LINNS_PIDAANTAX pt
LEFT JOIN SDEADM.LINNS_PIDRELATE pr ON pt.PID = pr.PID
LEFT JOIN SDEADM.LINNS_PIDMSTRS pm_current ON pt.PID = pm_current.PID
LEFT JOIN SDEADM.LINNS_PIDMSTRS pm_parent ON pr.PIDRELATE = pm_parent.PID
WHERE pt.AAN IN (SELECT AAN FROM @AANs)
ORDER BY pt.AAN, pr.RELNAME;

-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'STEP 3: What did the parent PID turn into?';
PRINT '        (All children of each parent PID via PIDRELATE)';
PRINT '============================================================================';
-- For infant parcels, look up the parent PID and find ALL its children
-- This shows the full subdivision: parent -> all infants
-- ============================================================================

WITH Parent_PIDs AS (
    -- Get the parent PIDs for our AANs
    SELECT DISTINCT
        pr.PIDRELATE AS Parent_PID
    FROM SDEADM.LINNS_PIDAANTAX pt
    INNER JOIN SDEADM.LINNS_PIDRELATE pr ON pt.PID = pr.PID
    WHERE pt.AAN IN (SELECT AAN FROM @AANs)
      AND pr.RELNAME = 'INFANT PARCEL'
)
SELECT
    pp.Parent_PID,
    pm_parent.STARTDATE AS Parent_Created,
    pr_children.PID AS Child_PID,
    pr_children.RELNAME AS Child_Relationship,
    pr_children.CRE_DATE AS Relationship_Created,
    pm_child.STARTDATE AS Child_Created,
    -- What AAN is currently tied to this child?
    pt_child.AAN AS Child_AAN,
    -- Is this child in the parcel fabric?
    CASE
        WHEN lpp.pid IS NOT NULL THEN 'YES'
        ELSE 'NO'
    END AS Child_In_Fabric
FROM Parent_PIDs pp
-- All children of this parent
INNER JOIN SDEADM.LINNS_PIDRELATE pr_children
    ON pp.Parent_PID = pr_children.PIDRELATE
    AND pr_children.RELNAME = 'INFANT PARCEL'
LEFT JOIN SDEADM.LINNS_PIDMSTRS pm_parent ON pp.Parent_PID = pm_parent.PID
LEFT JOIN SDEADM.LINNS_PIDMSTRS pm_child ON pr_children.PID = pm_child.PID
LEFT JOIN SDEADM.LINNS_PIDAANTAX pt_child ON pr_children.PID = pt_child.PID
LEFT JOIN SDEADM.LND_parcel_polygon lpp ON pr_children.PID = lpp.pid
ORDER BY pp.Parent_PID, pr_children.PID;

-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'STEP 4: Is the OLD parent PID still in the fabric / still has an AAN?';
PRINT '============================================================================';
-- Check if the parent PID still exists in the fabric and/or PIDAANTAX
-- If parent was removed from fabric before GIS ran, it wouldn't be in SAP
-- If parent's AAN was remapped before SQL ran, the INNER JOIN would fail
-- ============================================================================

WITH Parent_PIDs AS (
    SELECT DISTINCT
        pt.AAN,
        pr.PIDRELATE AS Parent_PID,
        pr.RELNAME,
        pr.CRE_DATE AS Relationship_Created
    FROM SDEADM.LINNS_PIDAANTAX pt
    INNER JOIN SDEADM.LINNS_PIDRELATE pr ON pt.PID = pr.PID
    WHERE pt.AAN IN (SELECT AAN FROM @AANs)
      AND pr.RELNAME IN ('INFANT PARCEL', 'CONDO UNIT PARCEL')
)
SELECT
    pp.AAN,
    pp.Parent_PID,
    pp.RELNAME,
    pp.Relationship_Created,
    pm.STARTDATE AS Parent_Created,
    -- Is parent still in the fabric?
    CASE
        WHEN lpp.pid IS NOT NULL THEN 'YES - still in fabric'
        ELSE 'NO - removed from fabric'
    END AS Parent_In_Fabric,
    -- Does parent still have an AAN mapping?
    pt_parent.AAN AS Parent_Current_AAN,
    CASE
        WHEN pt_parent.AAN IS NOT NULL THEN 'YES - still mapped to AAN ' + pt_parent.AAN
        ELSE 'NO - no AAN mapping (remapped to child PIDs)'
    END AS Parent_Has_AAN
FROM Parent_PIDs pp
LEFT JOIN SDEADM.LINNS_PIDMSTRS pm ON pp.Parent_PID = pm.PID
LEFT JOIN SDEADM.LND_parcel_polygon lpp ON pp.Parent_PID = lpp.pid
LEFT JOIN SDEADM.LINNS_PIDAANTAX pt_parent ON pp.Parent_PID = pt_parent.PID
ORDER BY pp.AAN;

-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'STEP 5: Timeline - diagnose why each AAN was missed';
PRINT '============================================================================';
-- Combines all timing info into a single view:
--   When was the parent created? When was it subdivided?
--   When was the child created? When did the GIS run?
--   Was the parent in the fabric at GIS time?
--   Was the AAN mapped to the right PID at SQL time?
-- ============================================================================

SELECT
    pt.AAN,
    -- Current state
    pt.PID AS Current_PID,
    pm_current.STARTDATE AS Current_PID_Created,
    pr.RELNAME AS Relationship,
    -- Parent state
    pr.PIDRELATE AS Parent_PID,
    pm_parent.STARTDATE AS Parent_PID_Created,
    pr.CRE_DATE AS Subdivision_Date,
    -- Fabric state
    CASE WHEN lpp_current.pid IS NOT NULL THEN 'YES' ELSE 'NO' END AS Current_PID_In_Fabric,
    CASE WHEN lpp_parent.pid IS NOT NULL THEN 'YES' ELSE 'NO' END AS Parent_PID_In_Fabric,
    -- AAN mapping state
    pt_parent.AAN AS Parent_Still_Has_AAN,
    -- Diagnosis: what happened at the Aug 2025 production run?
    CASE
        -- Regular parcel (no relationship) - should have been picked up directly
        WHEN pr.RELNAME IS NULL THEN
            CASE
                WHEN pm_current.STARTDATE > '2025-08-11'
                    THEN 'Current PID created AFTER Aug run - not in SAP table'
                ELSE 'PID existed at Aug run - check if it was in the boundary'
            END
        -- Infant parcel
        WHEN pr.RELNAME = 'INFANT PARCEL' THEN
            CASE
                WHEN pr.CRE_DATE > '2025-08-11' AND pm_current.STARTDATE > '2025-08-11'
                    THEN 'Subdivision happened AFTER Aug run. '
                       + 'Parent PID ' + CAST(pr.PIDRELATE AS VARCHAR)
                       + CASE
                            WHEN lpp_parent.pid IS NOT NULL THEN ' is still in fabric'
                            WHEN pt_parent.AAN IS NOT NULL THEN ' still has AAN but removed from fabric'
                            ELSE ' removed from fabric AND AAN remapped'
                         END
                WHEN pr.CRE_DATE <= '2025-08-11' AND pm_current.STARTDATE > '2025-08-11'
                    THEN 'Relationship created before Aug run but infant PID not yet in fabric. '
                       + 'Parent PID ' + CAST(pr.PIDRELATE AS VARCHAR)
                       + CASE
                            WHEN pt_parent.AAN IS NULL THEN ' - AAN already remapped (INNER JOIN gap)'
                            ELSE ' - AAN still on parent'
                         END
                ELSE 'Both relationship and PID existed before Aug run'
            END
        -- Condo unit
        WHEN pr.RELNAME = 'CONDO UNIT PARCEL' THEN
            CASE
                WHEN lpp_parent.pid IS NOT NULL THEN 'Common parcel in fabric - should be found'
                ELSE 'Common parcel NOT in fabric'
            END
        ELSE 'Check relationship type: ' + pr.RELNAME
    END AS Diagnosis
FROM SDEADM.LINNS_PIDAANTAX pt
LEFT JOIN SDEADM.LINNS_PIDRELATE pr ON pt.PID = pr.PID
LEFT JOIN SDEADM.LINNS_PIDMSTRS pm_current ON pt.PID = pm_current.PID
LEFT JOIN SDEADM.LINNS_PIDMSTRS pm_parent ON pr.PIDRELATE = pm_parent.PID
LEFT JOIN SDEADM.LND_parcel_polygon lpp_current ON pt.PID = lpp_current.pid
LEFT JOIN SDEADM.LND_parcel_polygon lpp_parent ON pr.PIDRELATE = lpp_parent.pid
LEFT JOIN SDEADM.LINNS_PIDAANTAX pt_parent ON pr.PIDRELATE = pt_parent.PID
WHERE pt.AAN IN (SELECT AAN FROM @AANs)
ORDER BY pt.AAN;

-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'STEP 6: Check if parent PIDs were in the SAP table (GIS output)';
PRINT '============================================================================';
-- If SAP_ADM_tax_designation still exists, check whether the parent PIDs
-- made it into the GIS Identity output. If parent PID IS in SAP but NOT
-- in PIDAANTAX, we have proof of the INNER JOIN gap.
-- ============================================================================

-- Check if SAP table exists first
IF OBJECT_ID('SDEADM.SAP_ADM_tax_designation', 'U') IS NOT NULL
BEGIN
    PRINT 'SAP_ADM_tax_designation exists - checking for parent PIDs...';

    WITH Parent_PIDs AS (
        SELECT DISTINCT
            pt.AAN,
            pt.PID AS Current_PID,
            pr.PIDRELATE AS Parent_PID,
            pr.RELNAME
        FROM SDEADM.LINNS_PIDAANTAX pt
        INNER JOIN SDEADM.LINNS_PIDRELATE pr ON pt.PID = pr.PID
        WHERE pt.AAN IN (SELECT AAN FROM @AANs)
          AND pr.RELNAME = 'INFANT PARCEL'
    )
    SELECT
        pp.AAN,
        pp.Current_PID,
        pp.Parent_PID,
        -- Is parent in SAP (GIS found it)?
        CASE
            WHEN sap_parent.pid IS NOT NULL THEN 'YES - GIS found parent PID'
            ELSE 'NO - parent PID not in GIS output'
        END AS Parent_In_SAP,
        sap_parent.AREARATE_CODE AS Parent_SAP_Rate_Code,
        -- Is current (infant) PID in SAP?
        CASE
            WHEN sap_current.pid IS NOT NULL THEN 'YES - GIS found infant PID'
            ELSE 'NO - infant PID not in GIS output'
        END AS Infant_In_SAP,
        sap_current.AREARATE_CODE AS Infant_SAP_Rate_Code,
        -- Does parent still have an AAN in PIDAANTAX?
        pt_parent.AAN AS Parent_AAN_in_PIDAANTAX,
        -- Diagnosis
        CASE
            WHEN sap_parent.pid IS NOT NULL AND pt_parent.AAN IS NULL
                THEN 'INNER JOIN GAP: Parent in SAP but AAN remapped away'
            WHEN sap_parent.pid IS NOT NULL AND pt_parent.AAN IS NOT NULL
                THEN 'Parent in SAP and has AAN - should have been caught'
            WHEN sap_parent.pid IS NULL AND sap_current.pid IS NOT NULL
                THEN 'Infant in SAP (parent removed) - check PIDAANTAX timing'
            WHEN sap_parent.pid IS NULL AND sap_current.pid IS NULL
                THEN 'Neither parent nor infant in SAP - both missed by GIS'
            ELSE 'Unknown'
        END AS SAP_Diagnosis
    FROM Parent_PIDs pp
    LEFT JOIN SDEADM.SAP_ADM_tax_designation sap_parent
        ON pp.Parent_PID = sap_parent.pid
    LEFT JOIN SDEADM.SAP_ADM_tax_designation sap_current
        ON pp.Current_PID = sap_current.pid
    LEFT JOIN SDEADM.LINNS_PIDAANTAX pt_parent
        ON pp.Parent_PID = pt_parent.PID
    ORDER BY pp.AAN;
END
ELSE
BEGIN
    PRINT 'SAP_ADM_tax_designation does not exist - cannot check GIS output.';
    PRINT 'The SAP table is recreated each GIS run, so it reflects the MOST RECENT run only.';
END

-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'STEP 7: Check if parent PIDs made it to the final area rates table';
PRINT '============================================================================';
-- Check AR_taxdes_FINAL_SAP and Area_Rates_PID_AAN for the parent PIDs
-- If parent PID is in GIS output but NOT in final table, the SQL pipeline
-- dropped it (likely at the INNER JOIN in ar_taxdes2_AAN_SAP.sql)
-- ============================================================================

WITH All_PIDs AS (
    -- Current PIDs from our AANs
    SELECT
        pt.AAN,
        pt.PID,
        'Current PID' AS PID_Type
    FROM SDEADM.LINNS_PIDAANTAX pt
    WHERE pt.AAN IN (SELECT AAN FROM @AANs)

    UNION ALL

    -- Parent PIDs
    SELECT
        pt.AAN,
        pr.PIDRELATE AS PID,
        'Parent PID' AS PID_Type
    FROM SDEADM.LINNS_PIDAANTAX pt
    INNER JOIN SDEADM.LINNS_PIDRELATE pr ON pt.PID = pr.PID
    WHERE pt.AAN IN (SELECT AAN FROM @AANs)
      AND pr.RELNAME IN ('INFANT PARCEL', 'CONDO UNIT PARCEL')
)
SELECT
    ap.AAN,
    ap.PID,
    ap.PID_Type,
    -- In final taxdes table?
    CASE
        WHEN tf.PID IS NOT NULL THEN 'YES (ARCODE: ' + tf.ARCODE + ')'
        ELSE 'NO'
    END AS In_taxdes_FINAL,
    -- In aggregate area rates table?
    CASE
        WHEN ar.PID IS NOT NULL THEN 'YES'
        ELSE 'NO'
    END AS In_Area_Rates_PID_AAN
FROM All_PIDs ap
LEFT JOIN SDEADM.AR_taxdes_FINAL_SAP tf ON ap.PID = tf.PID
LEFT JOIN SDEADM.Area_Rates_PID_AAN ar ON ap.PID = ar.PID
ORDER BY ap.AAN, ap.PID_Type;

-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'STEP 8: SUMMARY - Root cause for each AAN';
PRINT '============================================================================';
-- ============================================================================

SELECT
    pt.AAN,
    pt.PID AS Current_PID,
    pm_current.STARTDATE AS Current_PID_Created,
    ISNULL(pr.RELNAME, 'Regular Parcel') AS Relationship,
    pr.PIDRELATE AS Parent_PID,
    pr.CRE_DATE AS Subdivision_Date,
    -- Fabric status
    CASE WHEN lpp_current.pid IS NOT NULL THEN 'Yes' ELSE 'No' END AS Current_In_Fabric,
    CASE WHEN lpp_parent.pid IS NOT NULL THEN 'Yes' WHEN pr.PIDRELATE IS NULL THEN 'N/A' ELSE 'No' END AS Parent_In_Fabric,
    -- Root cause determination
    CASE
        WHEN pr.RELNAME IS NULL AND pm_current.STARTDATE <= '2025-08-11'
            THEN 'INVESTIGATE: Regular PID existed before run - why was it missed?'

        WHEN pr.RELNAME IS NULL AND pm_current.STARTDATE > '2025-08-11'
            THEN 'NEW PID: Created ' + CONVERT(VARCHAR, pm_current.STARTDATE, 23)
               + ' after Aug 2025 run'

        WHEN pr.RELNAME = 'INFANT PARCEL'
         AND pr.CRE_DATE > '2025-08-11'
         AND lpp_parent.pid IS NOT NULL
         AND pt_parent.AAN IS NOT NULL
            THEN 'TIMING: Subdivision after Aug run. Parent still in fabric with AAN.'
               + ' Re-running analysis should pick this up.'

        WHEN pr.RELNAME = 'INFANT PARCEL'
         AND pr.CRE_DATE > '2025-08-11'
         AND lpp_parent.pid IS NOT NULL
         AND pt_parent.AAN IS NULL
            THEN 'TIMING GAP: Subdivision after Aug run. Parent in fabric but AAN remapped.'
               + ' GIS would find parent, but SQL INNER JOIN drops it (no AAN for parent PID).'

        WHEN pr.RELNAME = 'INFANT PARCEL'
         AND pr.CRE_DATE > '2025-08-11'
         AND lpp_parent.pid IS NULL
         AND pt_parent.AAN IS NULL
            THEN 'TIMING GAP: Subdivision after Aug run. Parent removed from fabric AND AAN remapped.'
               + ' Neither old nor new PID would be picked up.'

        WHEN pr.RELNAME = 'INFANT PARCEL'
         AND pr.CRE_DATE <= '2025-08-11'
            THEN 'Subdivision before Aug run. Check if parent was in fabric at run time.'

        WHEN pr.RELNAME = 'CONDO UNIT PARCEL'
         AND lpp_parent.pid IS NOT NULL
            THEN 'CONDO: Common parcel in fabric - should be found via condo pipeline.'

        WHEN pr.RELNAME = 'CONDO UNIT PARCEL'
         AND lpp_parent.pid IS NULL
            THEN 'CONDO: Common parcel NOT in fabric - condo pipeline would miss this.'

        ELSE 'Review manually: ' + ISNULL(pr.RELNAME, 'NULL')
    END AS Root_Cause
FROM SDEADM.LINNS_PIDAANTAX pt
LEFT JOIN SDEADM.LINNS_PIDRELATE pr ON pt.PID = pr.PID
LEFT JOIN SDEADM.LINNS_PIDMSTRS pm_current ON pt.PID = pm_current.PID
LEFT JOIN SDEADM.LND_parcel_polygon lpp_current ON pt.PID = lpp_current.pid
LEFT JOIN SDEADM.LND_parcel_polygon lpp_parent ON pr.PIDRELATE = lpp_parent.pid
LEFT JOIN SDEADM.LINNS_PIDAANTAX pt_parent ON pr.PIDRELATE = pt_parent.PID
WHERE pt.AAN IN (SELECT AAN FROM @AANs)
ORDER BY
    CASE
        WHEN pr.RELNAME IS NULL THEN 3
        WHEN pr.RELNAME = 'INFANT PARCEL' THEN 1
        WHEN pr.RELNAME = 'CONDO UNIT PARCEL' THEN 2
        ELSE 4
    END,
    pt.AAN;

PRINT '';
PRINT '============================================================================';
PRINT 'HOW TO READ THESE RESULTS:';
PRINT '';
PRINT 'The area rates pipeline has two phases that use different data sources:';
PRINT '  Phase 1 (GIS): Identity analysis on LND_parcel_polygon -> SAP table';
PRINT '  Phase 2 (SQL): INNER JOIN SAP table to LINNS_PIDAANTAX on PID';
PRINT '';
PRINT 'When a parcel is subdivided:';
PRINT '  1. Old parent PID may be removed from LND_parcel_polygon';
PRINT '  2. New infant PIDs may not yet be added to LND_parcel_polygon';
PRINT '  3. AAN in LINNS_PIDAANTAX is remapped from parent PID to infant PID';
PRINT '';
PRINT 'If these changes happen between GIS runs, there are two failure modes:';
PRINT '  A) Parent still in fabric but AAN remapped -> GIS finds parent PID,';
PRINT '     but SQL INNER JOIN fails (no AAN for that PID anymore)';
PRINT '  B) Parent removed from fabric, infant not yet added -> GIS finds';
PRINT '     neither PID, so nothing enters the SAP table';
PRINT '';
PRINT 'Last production GIS run: 2026-01-22';
PRINT 'Previous production GIS run: 2025-08-11';
PRINT '============================================================================';
