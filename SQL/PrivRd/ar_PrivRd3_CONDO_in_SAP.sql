USE [GISRW01];
GO

-- Create tables AR_PrivRd_pid_000_SAP --> AR_PrivRd_pid_210_SAP

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

    PRINT 'Creating table: SDEADM.AR_PrivRd_R' + RIGHT(@tableName, 3) + '_CONDO_in_SAP';

    -- Generate the dynamic SQL statement
    SET @sqlStatement = '
    IF OBJECT_ID(''SDEADM.AR_PrivRd_R' + RIGHT(@tableName, 3) + '_CONDO_in_SAP'', ''U'') IS NOT NULL
        DROP TABLE SDEADM.AR_PrivRd_R' + RIGHT(@tableName, 3) + '_CONDO_in_SAP;

    SELECT t.PID, t.PIDRELATE, t.RELNAME, u.arcode
        INTO SDEADM.AR_PrivRd_R' + RIGHT(@tableName, 3) + '_CONDO_in_SAP
        FROM SDEADM.AR_PrivRd_pid_R' + RIGHT(@tableName, 3) + '_SAP u, SDEADM.linns_pidrelate t
        WHERE u.pid = t.pid
        AND t.RELNAME = ''CONDO COMMON PARCEL'';

    SELECT * FROM SDEADM.AR_PrivRd_R' + RIGHT(@tableName, 3) + '_CONDO_in_SAP;';

    -- Execute the dynamic SQL statement
    EXEC sp_executesql @sqlStatement;

    -- Fetch the next table name
    FETCH NEXT FROM tableCursor INTO @tableName;
END

-- Close and deallocate the cursor
CLOSE tableCursor;
DEALLOCATE tableCursor;
