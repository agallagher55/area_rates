USE [GISRW01];
GO

DECLARE @tableName VARCHAR(100);
DECLARE @sqlStatement NVARCHAR(MAX);

-- Create a cursor to iterate over the table names
DECLARE tableCursor CURSOR FOR
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE 'SAP_PRIVRD_R___';  -- Get all tables that start with

-- Open the cursor
OPEN tableCursor;

-- Fetch the first table name
FETCH NEXT FROM tableCursor INTO @tableName;

-- Loop through each table
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Creating table: AR_PrivRd_pid_R' + RIGHT(@tableName, 3) + '_SAP';

    -- Generate the dynamic SQL statement
    SET @sqlStatement = N'
    IF OBJECT_ID(''SDEADM.AR_PrivRd_pid_R' + RIGHT(@tableName, 3) + '_SAP'', ''U'') IS NOT NULL
        DROP TABLE SDEADM.AR_PrivRd_pid_R' + RIGHT(@tableName, 3) + '_SAP;

    SELECT pid, AREARATE_CODE AS ARCODE
    INTO SDEADM.AR_PrivRd_pid_R' + RIGHT(@tableName, 3) + '_SAP
    FROM (
        SELECT pid, AREARATE_CODE, shape_area,
               ROW_NUMBER() OVER (
               PARTITION BY pid ORDER BY shape_area DESC
               ) AS rn
        FROM SDEADM.' + QUOTENAME(@tableName) + '
    ) AS subquery
    WHERE rn = 1;

    DELETE FROM SDEADM.AR_PrivRd_pid_R' + RIGHT(@tableName, 3) + '_SAP
    WHERE arcode IS NULL;

    SELECT * FROM SDEADM.AR_PrivRd_pid_R' + RIGHT(@tableName, 3) + '_SAP;';

    -- Execute the dynamic SQL statement
    EXEC sp_executesql @sqlStatement;

    -- Fetch the next table name
    FETCH NEXT FROM tableCursor INTO @tableName;
END

-- Close and deallocate the cursor
CLOSE tableCursor;
DEALLOCATE tableCursor;
