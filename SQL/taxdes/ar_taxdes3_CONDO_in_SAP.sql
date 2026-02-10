USE [GISRW01];
GO

IF OBJECT_ID('[SDEADM].[AR_taxdes_CONDO_in_SAP]', 'U') IS NOT NULL
	DROP TABLE [SDEADM].[AR_taxdes_CONDO_in_SAP];

SELECT t.PID, t.PIDRELATE, t.RELNAME, u.arcode
    INTO [SDEADM].[AR_taxdes_CONDO_in_SAP]
    FROM [SDEADM].[AR_taxdes_pid_SAP] u, [SDEADM].[linns_pidrelate] t
    WHERE u.pid = t.pid
    and t.RELNAME = 'CONDO COMMON PARCEL'
;

SELECT * FROM [SDEADM].[AR_taxdes_CONDO_in_SAP];
