USE [GISRW01];
GO

-- Create tables AR_PrivRd_AAN_R000_SAP --> AR_PrivRd_AAN_R210_SAP

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

    PRINT 'Dropping table: SDEADM.AR_PrivRd_AAN_R' + RIGHT(@tableName, 3) + '_SAP';

    -- Generate the dynamic SQL statement
    SET @sqlStatement = '

	IF OBJECT_ID(''SDEADM.AR_PrivRd_AAN_R' + RIGHT(@tableName, 3) + '_SAP'', ''U'') IS NOT NULL
		DROP TABLE SDEADM.AR_PrivRd_AAN_R' + RIGHT(@tableName, 3) + '_SAP;

    SELECT ltrim(rtrim(t.AAN)) as "ACCTNO", u.PID, u.arcode
        INTO SDEADM.AR_PrivRd_AAN_R' + RIGHT(@tableName, 3) + '_SAP
        FROM SDEADM.AR_PrivRd_pid_R' + RIGHT(@tableName, 3) + '_SAP u, SDEADM.LINNS_PIDAANTAX t
        WHERE u.pid = t.pid;

    DELETE FROM SDEADM.AR_PrivRd_AAN_R' + RIGHT(@tableName, 3) + '_SAP
    WHERE ACCTNO IS NULL;

    SELECT * FROM SDEADM.AR_PrivRd_AAN_R' + RIGHT(@tableName, 3) + '_SAP;';

    -- Execute the dynamic SQL statement
    EXEC sp_executesql @sqlStatement;

    -- Fetch the next table name
    FETCH NEXT FROM tableCursor INTO @tableName;
END

-- Close and deallocate the cursor
CLOSE tableCursor;
DEALLOCATE tableCursor;