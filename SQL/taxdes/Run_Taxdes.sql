USE [GISRW01];
GO

DECLARE @tableName1 NVARCHAR(100) = 'SDEADM.AR_TAXDES_pid_SAP';
DECLARE @tableName2 NVARCHAR(100) = 'SDEADM.SAP_ADM_TAX_DESIGNATION';
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

-- AAN SAP
IF OBJECT_ID('[SDEADM].[AR_taxdes_AAN_SAP]', 'U') IS NOT NULL
DROP TABLE [SDEADM].[AR_taxdes_AAN_SAP];

SELECT LTRIM(RTRIM(l.AAN)) as "ACCTNO", a.PID, a.arcode
    INTO [SDEADM].[AR_taxdes_AAN_SAP]
    FROM [SDEADM].[AR_taxdes_pid_SAP] a, [SDEADM].[LINNS_PIDAANTAX] l
    WHERE a.pid = l.pid

DELETE FROM [SDEADM].[AR_taxdes_AAN_SAP]
WHERE ACCTNO IS NULL OR ACCTNO LIKE '';

-- CONDO IN SAP
-- Create new table to identify condo PIDs, using linns_pidrelate
-- Get all condo PIDs that fall within the area rate
IF OBJECT_ID('[SDEADM].[AR_taxdes_CONDO_in_SAP]', 'U') IS NOT NULL
	DROP TABLE [SDEADM].[AR_taxdes_CONDO_in_SAP];

SELECT l.PID, l.PIDRELATE, l.RELNAME, a.arcode
    INTO [SDEADM].[AR_taxdes_CONDO_in_SAP]
    FROM [SDEADM].[AR_taxdes_pid_SAP] a, [SDEADM].[linns_pidrelate] l
    WHERE a.pid = l.pid AND
        l.RELNAME = 'CONDO COMMON PARCEL'
;

-- CONDO AAN SAP
-- Get associated AANs for CONDO PIDs
-- Add AANs to AR PID condo table
IF OBJECT_ID('[SDEADM].[AR_taxdes_CONDO_AAN_SAP]', 'U') IS NOT NULL
	DROP TABLE [SDEADM].[AR_taxdes_CONDO_AAN_SAP];

SELECT LTRIM(RTRIM(l.AAN)) as "ACCTNO", a.PIDRELATE, a.pid, a.arcode
    INTO [SDEADM].[AR_taxdes_CONDO_AAN_SAP]
    FROM [SDEADM].[AR_taxdes_CONDO_in_SAP] a, [SDEADM].[LINNS_PIDAANTAX] l
    WHERE a.pidrelate = l.pid
;

DELETE FROM [SDEADM].[AR_taxdes_CONDO_AAN_SAP]
WHERE ACCTNO IS NULL OR ACCTNO LIKE '';

-- PREFINAL
-- 1. Create table to hold PID, ACCTNO, ARCODE from AR_taxdes_AAN_SAP and AR_taxdes_CONDO_AAN_SAP
IF OBJECT_ID('[SDEADM].[AR_taxdes_Pre_FINAL_SAP]', 'U') IS NOT NULL
	DROP TABLE [SDEADM].[AR_taxdes_Pre_FINAL_SAP];

CREATE TABLE [SDEADM].[AR_taxdes_Pre_FINAL_SAP]
(
   PID VARCHAR(8),
   ACCTNO VARCHAR(24),
   ARCODE VARCHAR(4),
   RECODE INT
);
   
INSERT INTO [SDEADM].[AR_taxdes_Pre_FINAL_SAP] (PID, ACCTNO, ARCODE)
       SELECT PID, ACCTNO, ARCODE FROM [SDEADM].[AR_taxdes_AAN_SAP]
;
	   
INSERT INTO [SDEADM].[AR_taxdes_Pre_FINAL_SAP] (PID, ACCTNO, ARCODE)
       SELECT PIDRELATE, ACCTNO, ARCODE FROM [SDEADM].[AR_taxdes_CONDO_AAN_SAP]
;

----------------------------------------------------------
-- 2. Code 'RECODE' values using ARCODE
UPDATE [SDEADM].[AR_taxdes_Pre_FINAL_SAP]
SET RECODE = 1
WHERE ARCODE = 'M010';

UPDATE [SDEADM].[AR_taxdes_Pre_FINAL_SAP]
SET RECODE = 2
WHERE ARCODE = 'M020';

UPDATE [SDEADM].[AR_taxdes_Pre_FINAL_SAP]
SET RECODE = 3
WHERE ARCODE = 'M030';

-----------------------------------------
-- 3. Create table to hold ACCTNO, RECODE(MAX for each ACCTNO) values. Get these values from AR_taxdes_Pre_FINAL_SAP (previous table)
DROP TABLE [SDEADM].[AR_taxdes_MAX_FINAL_SAP];

CREATE TABLE [SDEADM].[AR_taxdes_MAX_FINAL_SAP]
(
   ACCTNO VARCHAR(24),
   RECODE INT
);
   
INSERT INTO [SDEADM].[AR_taxdes_MAX_FINAL_SAP] (ACCTNO, RECODE)
	SELECT ACCTNO, MAX(RECODE) as MAXCODE
	FROM [SDEADM].[AR_taxdes_Pre_FINAL_SAP]
	GROUP BY ACCTNO
;

-------------------------------------------------
-- 4. 
-- This takes a long time to run.  There is likely a better way of doing this.
UPDATE a
SET a.RECODE = b.RECODE
FROM [SDEADM].[AR_taxdes_Pre_FINAL_SAP] a
INNER JOIN [SDEADM].[AR_taxdes_MAX_FINAL_SAP] b ON a.ACCTNO = b.ACCTNO
;

----------------------------------------------------------
-- 5. 
UPDATE [SDEADM].[AR_taxdes_Pre_FINAL_SAP]
SET ARCODE = 'M010'
WHERE RECODE = '1';

UPDATE [SDEADM].[AR_taxdes_Pre_FINAL_SAP]
SET ARCODE = 'M020'
WHERE RECODE = '2';

UPDATE [SDEADM].[AR_taxdes_Pre_FINAL_SAP]
SET ARCODE = 'M030'
WHERE RECODE = '3';

--------------------------------------------------
-- 6. 
DROP TABLE [SDEADM].[AR_taxdes_FINAL_SAP];
CREATE TABLE [SDEADM].[AR_taxdes_FINAL_SAP]
(
	PID VARCHAR(8),
	ACCTNO VARCHAR(24),
	ARCODE VARCHAR(4)
);
   
INSERT INTO [SDEADM].[AR_taxdes_FINAL_SAP]
	(PID, ACCTNO, ARCODE)
	SELECT PID, ACCTNO, ARCODE FROM [SDEADM].[AR_taxdes_Pre_FINAL_SAP]
;

-- FINAL
IF OBJECT_ID('[SDEADM].[AR_taxdes_FINAL_SAP]', 'U') IS NOT NULL
	DROP TABLE [SDEADM].[AR_taxdes_FINAL_SAP];

CREATE TABLE [SDEADM].[AR_taxdes_FINAL_SAP]
(
	   PID VARCHAR(8),
       ACCTNO VARCHAR(24),
       ARCODE VARCHAR(4)
);
   
INSERT INTO [SDEADM].[AR_taxdes_FINAL_SAP]
       (PID, ACCTNO, ARCODE)
       SELECT PID, ACCTNO, ARCODE FROM [SDEADM].[AR_taxdes_AAN_SAP]
       WHERE ACCTNO NOT LIKE '' AND ACCTNO IS NOT NULL AND ARCODE IS NOT NULL AND ARCODE NOT LIKE '';
	   
INSERT INTO [SDEADM].[AR_taxdes_FINAL_SAP]
       (PID, ACCTNO, ARCODE)
       SELECT PIDRELATE, ACCTNO, ARCODE FROM [SDEADM].[AR_taxdes_CONDO_AAN_SAP]
       WHERE ACCTNO NOT LIKE '' AND ACCTNO IS NOT NULL AND ARCODE IS NOT NULL AND ARCODE NOT LIKE '';
	   

-- CLEANUP
DROP TABLE SAP_ADM_TAX_DESIGNATION;
DROP TABLE AR_taxdes_pid_SAP;
DROP TABLE AR_taxdes_AAN_SAP;
DROP TABLE AR_taxdes_CONDO_in_SAP;
DROP TABLE AR_taxdes_CONDO_AAN_SAP;

