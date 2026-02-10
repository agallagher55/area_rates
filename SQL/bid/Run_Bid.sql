-- BID PID SAP
--The inner subquery selects the columns pid, AREARATE_CODE, and shape_area from SAP_bid.
--It also uses the ROW_NUMBER() function to assign a sequential number to each row within each group of pid,
--ordered by shape_area in descending order. The outer query then filters the results by
--selecting only the rows where rn (the row number) is equal to 1.
--This effectively selects the rows with the highest shape_area for each unique pid value.

USE [GISRW01];
GO

IF OBJECT_ID('[SDEADM].[AR_bid_pid_SAP]', 'U') IS NOT NULL
    DROP TABLE [SDEADM].[AR_bid_pid_SAP];

SELECT pid, AREARATE_CODE AS ARCODE
    INTO [SDEADM].[AR_bid_pid_SAP]
    FROM (
        SELECT pid, AREARATE_CODE, shape_area,
               ROW_NUMBER() OVER (
               PARTITION BY pid ORDER BY shape_area DESC
               ) AS rn
        FROM [SDEADM].[SAP_bid]
    ) AS subquery
    WHERE rn = 1;

DELETE FROM [SDEADM].[AR_bid_pid_SAP]
WHERE arcode IS NULL OR ARCODE LIKE '';

-- BID_AAN_SAP
--I added an IF condition to check if the table AR_bid_AAN_SAP exists before dropping it.
--Instead of using the CREATE TABLE ... AS SELECT ... syntax, I used the SELECT ... INTO ...
-- syntax to create the AR_bid_AAN_SAP table.

--The JOIN syntax was updated to use the explicit JOIN keyword with the ON clause to join the AR_bid_pid_SAP and LINNS_PIDAANTAX tables.

IF OBJECT_ID('[SDEADM].[AR_bid_AAN_SAP]', 'U') IS NOT NULL
	DROP TABLE [SDEADM].[AR_bid_AAN_SAP];

SELECT LTRIM(RTRIM(t.AAN)) AS ACCTNO, u.PID, u.arcode
INTO [SDEADM].[AR_bid_AAN_SAP]
FROM [SDEADM].[AR_bid_pid_SAP] u
JOIN [SDEADM].[LINNS_PIDAANTAX] t ON u.pid = t.pid;

DELETE FROM [SDEADM].[AR_bid_AAN_SAP]
WHERE ACCTNO IS NULL or ACCTNO LIKE '';

-- BID CONDO IN SAP
IF OBJECT_ID('[SDEADM].[AR_bid_CONDO_in_SAP]', 'U') IS NOT NULL
	DROP TABLE [SDEADM].[AR_bid_CONDO_in_SAP];

SELECT t.PID, t.PIDRELATE, t.RELNAME, u.arcode
    INTO [SDEADM].[AR_bid_CONDO_in_SAP]
    FROM [SDEADM].[AR_bid_pid_SAP] u, [SDEADM].[linns_pidrelate] t
    WHERE u.pid = t.pid
    and t.RELNAME = 'CONDO COMMON PARCEL';

-- BID CONDO AAN SAP
IF OBJECT_ID('[SDEADM].[AR_bid_CONDO_AAN_SAP]', 'U') IS NOT NULL
	DROP TABLE [SDEADM].[AR_bid_CONDO_AAN_SAP];

SELECT LTRIM(RTRIM(t.AAN)) as "ACCTNO", u.PIDRELATE, u.pid, u.arcode
INTO [SDEADM].[AR_bid_CONDO_AAN_SAP]
FROM [SDEADM].[AR_bid_CONDO_in_SAP] u, [SDEADM].[LINNS_PIDAANTAX] t
WHERE u.pidrelate = t.pid;

DELETE FROM [SDEADM].[AR_bid_CONDO_AAN_SAP]
WHERE ACCTNO IS NULL OR ACCTNO LIKE '';

--BID FINAL
DROP TABLE [SDEADM].[AR_BID_FINAL_SAP];

CREATE TABLE [SDEADM].[AR_BID_FINAL_SAP]
(
	   PID VARCHAR(8),
       ACCTNO VARCHAR(24),
       ARCODE VARCHAR(4)
);

INSERT INTO [SDEADM].[AR_BID_FINAL_SAP]
       (PID, ACCTNO, ARCODE)
       SELECT PID, ACCTNO, ARCODE FROM [SDEADM].[AR_bid_AAN_SAP]
;
	   
INSERT INTO [SDEADM].[AR_BID_FINAL_SAP]
       (PID, ACCTNO, ARCODE)
       SELECT PIDRELATE, ACCTNO, ARCODE FROM [SDEADM].[AR_bid_CONDO_AAN_SAP]
;

-- CLEAN
-- DROP TABLE SAP_bid;  -- do not delete. Get's created in spatial analysis
DROP TABLE AR_bid_pid_SAP;
DROP TABLE AR_bid_AAN_SAP;
DROP TABLE AR_bid_CONDO_in_SAP;
DROP TABLE AR_bid_CONDO_AAN_SAP;
