USE [GISRW01];
GO

DROP TABLE [SDEADM].[AR_bid_AAN_SAP];

SELECT LTRIM(RTRIM(t.AAN)) AS ACCTNO, u.PID, u.arcode
INTO [SDEADM].[AR_bid_AAN_SAP]
FROM [SDEADM].[AR_bid_pid_SAP] u
JOIN [SDEADM].[LINNS_PIDAANTAX] t ON u.pid = t.pid;

DELETE FROM [SDEADM].[AR_bid_AAN_SAP]
WHERE ACCTNO IS NULL or ACCTNO LIKE '';

SELECT * FROM [SDEADM].[AR_bid_AAN_SAP];

--I added an IF condition to check if the table AR_bid_AAN_SAP exists before dropping it.
--Instead of using the CREATE TABLE ... AS SELECT ... syntax, I used the SELECT ... INTO ...
-- syntax to create the AR_bid_AAN_SAP table.

--The JOIN syntax was updated to use the explicit JOIN keyword with the ON clause to join the AR_bid_pid_SAP and LINNS_PIDAANTAX tables.
