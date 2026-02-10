USE [GISRW01];
GO

DECLARE @tableName1 NVARCHAR(100) = 'SDEADM.AR_TRANSIT_pid_SAP';
DECLARE @tableName2 NVARCHAR(100) = 'SDEADM.SAP_TRANSIT';
DECLARE @sql NVARCHAR(MAX);

BEGIN TRY
    -------------------------------------------------------------------------
    -- DROP + RECREATE PID -> ARCODE TABLE
    -------------------------------------------------------------------------
    IF OBJECT_ID(@tableName1, 'U') IS NOT NULL
    BEGIN
        SET @sql = 'DROP TABLE ' + @tableName1 + ';';
        EXEC sp_executesql @sql;
        PRINT 'Dropped table: ' + @tableName1;
    END
    ELSE
    BEGIN
        PRINT 'Table does not exist: ' + @tableName1;
    END

    SET @sql = '
        SELECT  t2.pid,
                MIN(t2.AREARATE_CODE) AS ARCODE,
                MAX(t2.shape_area)    AS AREA
        INTO ' + @tableName1 + '
        FROM (
            SELECT  t1.pid,
                    t1.AREARATE_CODE,
                    t1.shape_area,
                    ROW_NUMBER() OVER (PARTITION BY t1.pid ORDER BY t1.shape_area DESC) AS rn
            FROM ' + @tableName2 + ' t1
        ) AS t2
        WHERE t2.rn = 1
          AND NULLIF(LTRIM(RTRIM(t2.AREARATE_CODE)), '''') IS NOT NULL
        GROUP BY t2.pid;';
    EXEC sp_executesql @sql;

    PRINT 'Created table: ' + @tableName1;

    -------------------------------------------------------------------------
    -- AAN SAP
    -------------------------------------------------------------------------
    IF OBJECT_ID('[SDEADM].[AR_TRANSIT_AAN_SAP]', 'U') IS NOT NULL
        DROP TABLE [SDEADM].[AR_TRANSIT_AAN_SAP];

    SELECT  LTRIM(RTRIM(t.AAN)) AS ACCTNO,
            u.PID,
            u.ARCODE
    INTO [SDEADM].[AR_TRANSIT_AAN_SAP]
    FROM [SDEADM].[AR_TRANSIT_pid_SAP] u
    JOIN [SDEADM].[LINNS_PIDAANTAX] t
        ON u.PID = t.PID;

    -- Remove bad rows (NULL/blank/whitespace)
    DELETE FROM [SDEADM].[AR_TRANSIT_AAN_SAP]
    WHERE NULLIF(LTRIM(RTRIM(ACCTNO)), '') IS NULL
       OR NULLIF(LTRIM(RTRIM(ARCODE)), '') IS NULL;

    -------------------------------------------------------------------------
    -- CONDO IN SAP
    -------------------------------------------------------------------------
    IF OBJECT_ID('[SDEADM].[AR_TRANSIT_CONDO_in_SAP]', 'U') IS NOT NULL
        DROP TABLE [SDEADM].[AR_TRANSIT_CONDO_in_SAP];

    SELECT  t.PID,
            t.PIDRELATE,
            t.RELNAME,
            u.ARCODE
    INTO [SDEADM].[AR_TRANSIT_CONDO_in_SAP]
    FROM [SDEADM].[AR_TRANSIT_pid_SAP] u
    JOIN [SDEADM].[linns_pidrelate] t
        ON u.PID = t.PID
    WHERE t.RELNAME = 'CONDO COMMON PARCEL';

    -------------------------------------------------------------------------
    -- CONDO AAN SAP
    -------------------------------------------------------------------------
    IF OBJECT_ID('[SDEADM].[AR_TRANSIT_CONDO_AAN_SAP]', 'U') IS NOT NULL
        DROP TABLE [SDEADM].[AR_TRANSIT_CONDO_AAN_SAP];

    SELECT  LTRIM(RTRIM(t.AAN)) AS ACCTNO,
            u.PIDRELATE,
            u.PID,
            u.ARCODE
    INTO [SDEADM].[AR_TRANSIT_CONDO_AAN_SAP]
    FROM [SDEADM].[AR_TRANSIT_CONDO_in_SAP] u
    JOIN [SDEADM].[LINNS_PIDAANTAX] t
        ON u.PIDRELATE = t.PID;

    -- Remove bad rows (NULL/blank/whitespace)
    DELETE FROM [SDEADM].[AR_TRANSIT_CONDO_AAN_SAP]
    WHERE NULLIF(LTRIM(RTRIM(ACCTNO)), '') IS NULL
       OR NULLIF(LTRIM(RTRIM(ARCODE)), '') IS NULL;

    -------------------------------------------------------------------------
    -- FINAL SAP
    -------------------------------------------------------------------------
    IF OBJECT_ID('[SDEADM].[AR_TRANSIT_FINAL_SAP]', 'U') IS NOT NULL
        DROP TABLE [SDEADM].[AR_TRANSIT_FINAL_SAP];

    CREATE TABLE [SDEADM].[AR_TRANSIT_FINAL_SAP]
    (
        PID    VARCHAR(8),
        ACCTNO VARCHAR(24),
        ARCODE VARCHAR(4)
    );

    -- Insert NON-CONDO rows
    INSERT INTO [SDEADM].[AR_TRANSIT_FINAL_SAP] (PID, ACCTNO, ARCODE)
    SELECT PID, ACCTNO, ARCODE
    FROM [SDEADM].[AR_TRANSIT_AAN_SAP]
    WHERE NULLIF(LTRIM(RTRIM(ACCTNO)), '') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(ARCODE)), '') IS NOT NULL;

    -- Insert CONDO rows (PIDRELATE becomes PID)
    INSERT INTO [SDEADM].[AR_TRANSIT_FINAL_SAP] (PID, ACCTNO, ARCODE)
    SELECT PIDRELATE, ACCTNO, ARCODE
    FROM [SDEADM].[AR_TRANSIT_CONDO_AAN_SAP]
    WHERE NULLIF(LTRIM(RTRIM(ACCTNO)), '') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(ARCODE)), '') IS NOT NULL;

    -------------------------------------------------------------------------
    -- CLEANUP
    -------------------------------------------------------------------------
    --DROP TABLE [SDEADM].[AR_TRANSIT_pid_SAP];
    --DROP TABLE [SDEADM].[AR_TRANSIT_AAN_SAP];
    --DROP TABLE [SDEADM].[AR_TRANSIT_CONDO_in_SAP];
    --DROP TABLE [SDEADM].[AR_TRANSIT_CONDO_AAN_SAP];

    PRINT 'Completed successfully.';
END TRY
BEGIN CATCH
    PRINT 'An error occurred: ' + ERROR_MESSAGE();
END CATCH;
GO
