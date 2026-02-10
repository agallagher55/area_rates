USE [GISRW01];
GO

DECLARE @tableName1 NVARCHAR(100) = 'SDEADM.AR_TRANSIT_pid_SAP';
DECLARE @tableName2 NVARCHAR(100) = 'SDEADM.SAP_TRANSIT';
DECLARE @sql NVARCHAR(MAX);

BEGIN TRY
    -- Check if the table exists before dropping it
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

    -- Create the table with dynamic table name
    SET @sql = '
        SELECT t2.pid,
               MIN(t2.AREARATE_CODE) AS ARCODE,
               MAX(t2.shape_area) AS AREA
        INTO ' + @tableName1 + '
        FROM (
            SELECT t1.pid,
                   t1.AREARATE_CODE,
                   t1.shape_area,
                   ROW_NUMBER() OVER (PARTITION BY t1.pid ORDER BY t1.shape_area DESC) AS rn
            FROM ' + @tableName2 + ' t1
        ) AS t2
        WHERE t2.rn = 1 AND t2.AREARATE_CODE IS NOT NULL
        GROUP BY t2.pid;';
    EXEC sp_executesql @sql;
    PRINT 'Created table: ' + @tableName1;

    -- Select from the created table
    SET @sql = 'SELECT * FROM ' + @tableName1 + ';';
    EXEC (@sql);
    PRINT 'Selected data from table: ' + @tableName1;
END TRY
BEGIN CATCH
    PRINT 'An error occurred: ' + ERROR_MESSAGE();
END CATCH;
