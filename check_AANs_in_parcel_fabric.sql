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
    pid_tax.TAXNO,
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
PRINT 'KEY INSIGHTS:';
PRINT '- CONDO UNIT PARCELs use the parent PID (PIDRELATE) for parcel fabric lookup';
PRINT '- INFANT PARCELs use the parent PID (PIDRELATE) for parcel fabric lookup';
PRINT '- Regular PIDs are looked up directly';
PRINT '- Step 6 shows which PIDs are MISSING from LND_parcel_polygon';
PRINT '============================================================================';
