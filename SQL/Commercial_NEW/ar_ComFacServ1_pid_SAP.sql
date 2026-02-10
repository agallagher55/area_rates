USE [GISRW01]
GO

DROP TABLE [SDEADM].[AR_COM_NEW_pid_SAP];

SELECT
    pid, MIN(AREARATE_CODE) AS ARCODE, MAX(shape_area) AS AREA
    INTO [SDEADM].[AR_COM_NEW_pid_SAP]
    FROM (
        SELECT
            pid,
            AREARATE_CODE,
            shape_area,
            ROW_NUMBER() OVER (PARTITION BY pid ORDER BY shape_area DESC) AS rn
        FROM [SDEADM].[SAP_ComFac_new]
    ) AS subquery
        WHERE rn = 1
        GROUP BY pid
        HAVING MIN(AREARATE_CODE) IS NOT NULL
;

SELECT * FROM [SDEADM].[AR_COM_NEW_pid_SAP];
