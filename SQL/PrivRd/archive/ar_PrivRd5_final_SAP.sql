USE [GISRW01];
GO

DROP TABLE [SDEADM].[AR_PrivRd_FINAL_SAP];
CREATE TABLE [SDEADM].[AR_PrivRd_FINAL_SAP]
(
	   PID VARCHAR(8),
       ACCTNO VARCHAR(24),
       ARCODE VARCHAR(4)
);

--------------------------------------------------------------

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

    -- Generate the dynamic SQL statement
    SET @sqlStatement = '

    INSERT INTO SDEADM.AR_PrivRd_FINAL_SAP
           (PID, ACCTNO, ARCODE)
           SELECT PID, ACCTNO, ARCODE FROM SDEADM.AR_PrivRd_AAN_R' + RIGHT(@tableName, 3) + '_SAP;

    SELECT * FROM SDEADM.AR_PrivRd_FINAL_SAP;';

    -- Execute the dynamic SQL statement
    EXEC sp_executesql @sqlStatement;

    -- Fetch the next table name
    FETCH NEXT FROM tableCursor INTO @tableName;
END

-- Close and deallocate the cursor
CLOSE tableCursor;
DEALLOCATE tableCursor;

------------------------------------------------------------------
DROP TABLE [SDEADM].[AR_PrivRd_FINAL_SAP];
CREATE TABLE [SDEADM].[AR_PrivRd_FINAL_SAP]
(
	   PID VARCHAR(8),
       ACCTNO VARCHAR(24),
       ARCODE VARCHAR(4)
);

  USE [GISRW01];
GO

-- Insert data into AR_PrivRd_FINAL_SAP
INSERT INTO [SDEADM].[AR_PrivRd_FINAL_SAP]
       (PID, ACCTNO, ARCODE)
SELECT PID, ACCTNO, ARCODE FROM [SDEADM].[AR_PrivRd_AAN_R210_SAP];

INSERT INTO [SDEADM].[AR_PrivRd_FINAL_SAP]
       (PID, ACCTNO, ARCODE)
SELECT PID, ACCTNO, ARCODE FROM [SDEADM].[AR_PrivRd_AAN_R000_SAP];

INSERT INTO [SDEADM].[AR_PrivRd_FINAL_SAP]
       (PID, ACCTNO, ARCODE)
SELECT PIDRELATE, ACCTNO, ARCODE FROM [SDEADM].[AR_PrivRd_R000_CONDO_AAN_SAP];

-- ... (repeat the insert statements for other tables)

INSERT INTO [SDEADM].[AR_PrivRd_FINAL_SAP]
       (PID, ACCTNO, ARCODE)
SELECT PID, ACCTNO, ARCODE FROM [SDEADM].[AR_PrivRd_AAN_R210_SAP];

INSERT INTO [SDEADM].[AR_PrivRd_FINAL_SAP]
       (PID, ACCTNO, ARCODE)
SELECT PIDRELATE, ACCTNO, ARCODE FROM [SDEADM].[AR_PrivRd_R210_CONDO_AAN_SAP];

