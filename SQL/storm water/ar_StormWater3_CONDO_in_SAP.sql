-- Create new table to identify condo PIDs, using linns_pidrelate
-- Get all condo PIDs that fall within the area rate
USE [GISRW01];

IF OBJECT_ID('[SDEADM].[AR_STORMWATER_CONDO_in_SAP]', 'U') IS NOT NULL
	DROP TABLE [SDEADM].[AR_STORMWATER_CONDO_in_SAP];

SELECT l.PID, l.PIDRELATE, l.RELNAME, a.arcode
    INTO [SDEADM].[AR_STORMWATER_CONDO_in_SAP]
    FROM [SDEADM].[AR_STORMWATER_pid_SAP] a, [SDEADM].[linns_pidrelate] l
    WHERE a.pid = l.pid AND
        l.RELNAME = 'CONDO COMMON PARCEL'
;

SELECT * FROM [SDEADM].[AR_STORMWATER_CONDO_in_SAP];

