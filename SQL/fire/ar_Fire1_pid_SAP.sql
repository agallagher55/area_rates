USE [GISRW01];
GO

-- Drop the table if it exists
IF OBJECT_ID('sdeadm.AR_Fire_pid_SAP', 'U') IS NOT NULL
    DROP TABLE sdeadm.AR_Fire_pid_SAP;
GO

-- Create the table using SELECT INTO syntax
;WITH MaxShapeAreas AS (
    SELECT 
        pid, 
        AREARATE_CODE AS ARCODE,
        shape_area,
        ROW_NUMBER() OVER (PARTITION BY pid ORDER BY shape_area DESC) AS rn
    FROM sdeadm.SAP_FIRE_PROTECTION
)
SELECT pid, ARCODE
INTO sdeadm.AR_Fire_pid_SAP
FROM MaxShapeAreas
WHERE rn = 1;
	   
-- Delete rows where arcode is NULL
DELETE FROM sdeadm.AR_Fire_pid_SAP
WHERE arcode IS NULL or ARCODE like '';

SELECT *
FROM sdeadm.AR_Fire_pid_SAP