USE [GISRW01];
GO

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

SELECT *
FROM [SDEADM].[AR_taxdes_FINAL_SAP]