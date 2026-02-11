-- ============================================================================
-- AAN to PID to Parcel Fabric Lookup
-- Purpose: Find which PIDs are associated with AANs and check if they exist
--          in the parcel fabric (LND_parcel_polygon)
-- ============================================================================

-- List of AANs we're investigating
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

PRINT '============================================================================';
PRINT 'STEP 1: Get PIDs from AANs (via LINNS_PIDAANTAX)';
PRINT '============================================================================';

SELECT
    pid_tax.AAN,
    pid_tax.PID,
    pid_tax.TAXCONFIRM,
    'Direct PID from AAN lookup' AS Source
FROM SDEADM.LINNS_PIDAANTAX AS pid_tax
WHERE pid_tax.AAN IN (SELECT AAN FROM @AANs)
ORDER BY pid_tax.AAN, pid_tax.PID;

PRINT '';
PRINT '============================================================================';
PRINT 'STEP 2: Check PID Relationships (Condo Units, Infant Parcels)';
PRINT '============================================================================';

SELECT
    pid_tax.AAN,
    pid_tax.PID AS Unit_PID,
    pid_relate.PIDRELATE AS Parent_PID,
    pid_relate.RELNAME AS Relationship_Type,
    pid_relate.CRE_DATE AS Relationship_Created,
    CASE
        WHEN pid_relate.RELNAME = 'CONDO UNIT PARCEL' THEN 'Use Parent PID for parcel fabric lookup'
        WHEN pid_relate.RELNAME = 'INFANT PARCEL' THEN 'Use Parent PID for parcel fabric lookup'
        WHEN pid_relate.RELNAME = 'CONDO COMMON PARCEL' THEN 'This IS the parent - use this PID'
        ELSE 'Use Unit PID directly'
    END AS Parcel_Fabric_Strategy
FROM SDEADM.LINNS_PIDAANTAX AS pid_tax
LEFT JOIN SDEADM.LINNS_PIDRELATE AS pid_relate
    ON pid_tax.PID = pid_relate.PID
WHERE pid_tax.AAN IN (SELECT AAN FROM @AANs)
ORDER BY pid_tax.AAN, pid_relate.RELNAME;

PRINT '';
PRINT '============================================================================';
PRINT 'STEP 3: Determine which PID to lookup in parcel fabric';
PRINT '============================================================================';

-- Create a lookup that uses the correct PID for parcel fabric checks
WITH PID_Lookup AS (
    SELECT
        pid_tax.AAN,
        pid_tax.PID AS Original_PID,
        CASE
            -- For condo units and infant parcels, use the parent PID
            WHEN pid_relate.RELNAME IN ('CONDO UNIT PARCEL', 'INFANT PARCEL')
                THEN pid_relate.PIDRELATE
            -- For everything else (including NULL relationships), use the original PID
            ELSE pid_tax.PID
        END AS Parcel_Fabric_PID,
        pid_relate.RELNAME AS Relationship_Type
    FROM SDEADM.LINNS_PIDAANTAX AS pid_tax
    LEFT JOIN SDEADM.LINNS_PIDRELATE AS pid_relate
        ON pid_tax.PID = pid_relate.PID
    WHERE pid_tax.AAN IN (SELECT AAN FROM @AANs)
)
SELECT
    AAN,
    Original_PID,
    Parcel_Fabric_PID,
    Relationship_Type,
    CASE
        WHEN Original_PID = Parcel_Fabric_PID THEN 'Direct lookup'
        ELSE 'Using parent PID'
    END AS Lookup_Method
FROM PID_Lookup
ORDER BY AAN, Original_PID;

PRINT '';
PRINT '============================================================================';
PRINT 'STEP 4: Check if PIDs exist in LND_parcel_polygon (Parcel Fabric)';
PRINT '============================================================================';

WITH PID_Lookup AS (
    SELECT
        pid_tax.AAN,
        pid_tax.PID AS Original_PID,
        CASE
            WHEN pid_relate.RELNAME IN ('CONDO UNIT PARCEL', 'INFANT PARCEL')
                THEN pid_relate.PIDRELATE
            ELSE pid_tax.PID
        END AS Parcel_Fabric_PID,
        pid_relate.RELNAME AS Relationship_Type
    FROM SDEADM.LINNS_PIDAANTAX AS pid_tax
    LEFT JOIN SDEADM.LINNS_PIDRELATE AS pid_relate
        ON pid_tax.PID = pid_relate.PID
    WHERE pid_tax.AAN IN (SELECT AAN FROM @AANs)
)
SELECT
    pl.AAN,
    pl.Original_PID,
    pl.Parcel_Fabric_PID,
    pl.Relationship_Type,
    CASE
        WHEN lpp.pid IS NOT NULL THEN 'YES - In Parcel Fabric'
        ELSE 'NO - NOT in Parcel Fabric'
    END AS In_Parcel_Fabric,
    lpp.SHAPE.STArea() AS Parcel_Area_SqFt,
    lpp.SHAPE.STIsValid() AS Geometry_Valid
FROM PID_Lookup pl
LEFT JOIN SDEADM.LND_parcel_polygon lpp
    ON pl.Parcel_Fabric_PID = lpp.pid
ORDER BY pl.AAN, pl.Original_PID;

PRINT '';
PRINT '============================================================================';
PRINT 'STEP 5: Summary - AANs and their Parcel Fabric Status';
PRINT '============================================================================';

WITH PID_Lookup AS (
    SELECT
        pid_tax.AAN,
        pid_tax.PID AS Original_PID,
        CASE
            WHEN pid_relate.RELNAME IN ('CONDO UNIT PARCEL', 'INFANT PARCEL')
                THEN pid_relate.PIDRELATE
            ELSE pid_tax.PID
        END AS Parcel_Fabric_PID,
        pid_relate.RELNAME AS Relationship_Type
    FROM SDEADM.LINNS_PIDAANTAX AS pid_tax
    LEFT JOIN SDEADM.LINNS_PIDRELATE AS pid_relate
        ON pid_tax.PID = pid_relate.PID
    WHERE pid_tax.AAN IN (SELECT AAN FROM @AANs)
)
SELECT
    pl.AAN,
    COUNT(DISTINCT pl.Original_PID) AS Num_PIDs_for_AAN,
    COUNT(DISTINCT pl.Parcel_Fabric_PID) AS Num_Fabric_PIDs,
    STRING_AGG(CAST(pl.Original_PID AS VARCHAR), ', ') AS All_Original_PIDs,
    STRING_AGG(CAST(pl.Parcel_Fabric_PID AS VARCHAR), ', ') AS All_Fabric_PIDs,
    CASE
        WHEN COUNT(lpp.pid) > 0 THEN 'YES - In Parcel Fabric'
        ELSE 'NO - NOT in Parcel Fabric'
    END AS Overall_Status
FROM PID_Lookup pl
LEFT JOIN SDEADM.LND_parcel_polygon lpp
    ON pl.Parcel_Fabric_PID = lpp.pid
GROUP BY pl.AAN
ORDER BY pl.AAN;

PRINT '';
PRINT '============================================================================';
PRINT 'STEP 6: Missing PIDs - Which Parcel Fabric PIDs are NOT in parcel layer?';
PRINT '============================================================================';

WITH PID_Lookup AS (
    SELECT
        pid_tax.AAN,
        pid_tax.PID AS Original_PID,
        CASE
            WHEN pid_relate.RELNAME IN ('CONDO UNIT PARCEL', 'INFANT PARCEL')
                THEN pid_relate.PIDRELATE
            ELSE pid_tax.PID
        END AS Parcel_Fabric_PID,
        pid_relate.RELNAME AS Relationship_Type
    FROM SDEADM.LINNS_PIDAANTAX AS pid_tax
    LEFT JOIN SDEADM.LINNS_PIDRELATE AS pid_relate
        ON pid_tax.PID = pid_relate.PID
    WHERE pid_tax.AAN IN (SELECT AAN FROM @AANs)
)
SELECT
    pl.AAN,
    pl.Original_PID,
    pl.Parcel_Fabric_PID,
    pl.Relationship_Type,
    'MISSING from LND_parcel_polygon' AS Issue
FROM PID_Lookup pl
LEFT JOIN SDEADM.LND_parcel_polygon lpp
    ON pl.Parcel_Fabric_PID = lpp.pid
WHERE lpp.pid IS NULL
ORDER BY pl.AAN, pl.Original_PID;

PRINT '';
PRINT '============================================================================';
PRINT 'STEP 7: FINAL SUMMARY REPORT - Complete Status for Each AAN';
PRINT '============================================================================';

WITH PID_Lookup AS (
    SELECT
        pid_tax.AAN,
        pid_tax.PID AS Original_PID,
        CASE
            WHEN pid_relate.RELNAME IN ('CONDO UNIT PARCEL', 'INFANT PARCEL')
                THEN pid_relate.PIDRELATE
            ELSE pid_tax.PID
        END AS Parcel_Fabric_PID,
        pid_relate.RELNAME AS Relationship_Type,
        pid_relate.PIDRELATE AS Parent_PID
    FROM SDEADM.LINNS_PIDAANTAX AS pid_tax
    LEFT JOIN SDEADM.LINNS_PIDRELATE AS pid_relate
        ON pid_tax.PID = pid_relate.PID
    WHERE pid_tax.AAN IN (SELECT AAN FROM @AANs)
)
SELECT
    pl.AAN,
    pl.Original_PID,
    -- Is it a condo?
    CASE
        WHEN pl.Relationship_Type LIKE '%CONDO%' THEN 'YES - Condo'
        WHEN pl.Relationship_Type = 'INFANT PARCEL' THEN 'NO - Infant Parcel'
        WHEN pl.Relationship_Type IS NULL THEN 'NO - Regular Parcel'
        ELSE 'NO - ' + pl.Relationship_Type
    END AS Is_Condo,
    -- What type of parcel relationship?
    ISNULL(pl.Relationship_Type, 'Regular Parcel (No Relationship)') AS Parcel_Type,
    -- Where was the PID taken from?
    CASE
        WHEN pl.Parent_PID IS NOT NULL THEN 'Parent PID: ' + CAST(pl.Parent_PID AS VARCHAR)
        ELSE 'Direct (Original PID)'
    END AS PID_Source,
    -- Which PID was used for lookup?
    pl.Parcel_Fabric_PID AS Lookup_PID,
    -- Is it in the parcel fabric?
    CASE
        WHEN lpp.pid IS NOT NULL THEN '✓ YES - Found in Parcel Fabric'
        ELSE '✗ NO - NOT Found'
    END AS In_Parcel_Fabric,
    -- Parcel area if found
    CASE
        WHEN lpp.pid IS NOT NULL THEN CAST(ROUND(lpp.SHAPE.STArea(), 2) AS VARCHAR) + ' sq ft'
        ELSE 'N/A (Not Found)'
    END AS Parcel_Area,
    -- Overall status
    CASE
        WHEN lpp.pid IS NOT NULL AND pl.Parent_PID IS NOT NULL THEN 'OK - Found via Parent'
        WHEN lpp.pid IS NOT NULL AND pl.Parent_PID IS NULL THEN 'OK - Found Direct'
        WHEN lpp.pid IS NULL AND pl.Parent_PID IS NOT NULL THEN 'MISSING - Parent Not in Fabric'
        WHEN lpp.pid IS NULL AND pl.Parent_PID IS NULL THEN 'MISSING - Not in Fabric'
        ELSE 'Unknown'
    END AS Status_Summary
FROM PID_Lookup pl
LEFT JOIN SDEADM.LND_parcel_polygon lpp
    ON pl.Parcel_Fabric_PID = lpp.pid
ORDER BY
    CASE WHEN lpp.pid IS NULL THEN 0 ELSE 1 END,  -- Missing ones first
    pl.AAN,
    pl.Original_PID;

PRINT '';
PRINT '============================================================================';
PRINT 'STEP 8: NOT FOUND ANYWHERE - Critical Missing PIDs';
PRINT '============================================================================';

WITH PID_Lookup AS (
    SELECT
        pid_tax.AAN,
        pid_tax.PID AS Original_PID,
        CASE
            WHEN pid_relate.RELNAME IN ('CONDO UNIT PARCEL', 'INFANT PARCEL')
                THEN pid_relate.PIDRELATE
            ELSE pid_tax.PID
        END AS Parcel_Fabric_PID,
        pid_relate.RELNAME AS Relationship_Type,
        pid_relate.PIDRELATE AS Parent_PID
    FROM SDEADM.LINNS_PIDAANTAX AS pid_tax
    LEFT JOIN SDEADM.LINNS_PIDRELATE AS pid_relate
        ON pid_tax.PID = pid_relate.PID
    WHERE pid_tax.AAN IN (SELECT AAN FROM @AANs)
)
SELECT
    pl.AAN,
    pl.Original_PID,
    pl.Parcel_Fabric_PID AS Missing_PID,
    ISNULL(pl.Relationship_Type, 'Regular Parcel') AS Parcel_Type,
    CASE
        WHEN pl.Parent_PID IS NOT NULL THEN 'Missing Parent PID: ' + CAST(pl.Parent_PID AS VARCHAR)
        ELSE 'Missing Original PID: ' + CAST(pl.Original_PID AS VARCHAR)
    END AS What_Is_Missing,
    'NOT FOUND in LND_parcel_polygon' AS Issue,
    CASE
        WHEN pl.Relationship_Type LIKE '%CONDO%' THEN 'Check if common parcel was created after GIS run'
        WHEN pl.Relationship_Type = 'INFANT PARCEL' THEN 'Check if parent parcel was created after GIS run'
        ELSE 'Check if parcel exists in system or needs to be added'
    END AS Recommended_Action
FROM PID_Lookup pl
LEFT JOIN SDEADM.LND_parcel_polygon lpp
    ON pl.Parcel_Fabric_PID = lpp.pid
WHERE lpp.pid IS NULL
ORDER BY pl.AAN, pl.Original_PID;

PRINT '';
PRINT '============================================================================';
PRINT 'STEP 9: AGGREGATE SUMMARY BY AAN';
PRINT '============================================================================';

WITH PID_Lookup AS (
    SELECT
        pid_tax.AAN,
        pid_tax.PID AS Original_PID,
        CASE
            WHEN pid_relate.RELNAME IN ('CONDO UNIT PARCEL', 'INFANT PARCEL')
                THEN pid_relate.PIDRELATE
            ELSE pid_tax.PID
        END AS Parcel_Fabric_PID,
        pid_relate.RELNAME AS Relationship_Type
    FROM SDEADM.LINNS_PIDAANTAX AS pid_tax
    LEFT JOIN SDEADM.LINNS_PIDRELATE AS pid_relate
        ON pid_tax.PID = pid_relate.PID
    WHERE pid_tax.AAN IN (SELECT AAN FROM @AANs)
)
SELECT
    pl.AAN,
    COUNT(DISTINCT pl.Original_PID) AS Total_PIDs,
    MAX(CASE WHEN pl.Relationship_Type LIKE '%CONDO%' THEN 'Condo'
             WHEN pl.Relationship_Type = 'INFANT PARCEL' THEN 'Infant'
             ELSE 'Regular' END) AS Type,
    SUM(CASE WHEN lpp.pid IS NOT NULL THEN 1 ELSE 0 END) AS PIDs_Found,
    SUM(CASE WHEN lpp.pid IS NULL THEN 1 ELSE 0 END) AS PIDs_Missing,
    CASE
        WHEN SUM(CASE WHEN lpp.pid IS NULL THEN 1 ELSE 0 END) = 0 THEN '✓ All Found'
        WHEN SUM(CASE WHEN lpp.pid IS NOT NULL THEN 1 ELSE 0 END) = 0 THEN '✗ None Found'
        ELSE '⚠ Partially Found'
    END AS Overall_Status,
    CAST(ROUND(
        100.0 * SUM(CASE WHEN lpp.pid IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*),
        1) AS VARCHAR) + '%' AS Percent_Found
FROM PID_Lookup pl
LEFT JOIN SDEADM.LND_parcel_polygon lpp
    ON pl.Parcel_Fabric_PID = lpp.pid
GROUP BY pl.AAN
ORDER BY PIDs_Missing DESC, pl.AAN;

PRINT '';
PRINT '============================================================================';
PRINT 'KEY INSIGHTS:';
PRINT '- CONDO UNIT PARCELs use the parent PID (PIDRELATE) for parcel fabric lookup';
PRINT '- INFANT PARCELs use the parent PID (PIDRELATE) for parcel fabric lookup';
PRINT '- Regular PIDs are looked up directly';
PRINT '- Step 7 shows detailed status for each AAN';
PRINT '- Step 8 shows PIDs NOT FOUND in LND_parcel_polygon';
PRINT '- Step 9 shows aggregate summary by AAN';
PRINT '============================================================================';
