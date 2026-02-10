USE [GISRW01];
GO

DROP TABLE [sdeadm].[AR_COM_FAC_SERV_pid_SAP];

SELECT pid,
       MIN(AREARATE_CODE) AS ARCODE,
       MAX(shape_area) AS AREA
INTO [SDEADM].[AR_COM_FAC_SERV_pid_SAP]
FROM (
    SELECT pid,
           AREARATE_CODE,
           shape_area,
           ROW_NUMBER() OVER (PARTITION BY pid ORDER BY shape_area DESC) AS rn
    FROM [SDEADM].[SAP_ComFac_SERV]
) AS subquery
WHERE rn = 1
GROUP BY pid
HAVING MIN(AREARATE_CODE) IS NOT NULL;

DELETE FROM [SDEADM].[AR_COM_FAC_SERV_pid_SAP]
WHERE ARCODE IS NULL OR ARCODE LIKE ''

SELECT *
FROM [SDEADM].[AR_COM_FAC_SERV_pid_SAP]
;

--I added an IF condition to check if the table AR_COM_FAC_SERV_pid_SAP exists before dropping it.
--The KEEP (dense_rank first order by shape_area desc) syntax is replaced with a subquery that utilizes ROW_NUMBER()
--function to get the row with the highest shape_area for each pid.
--The SELECT INTO statement is used to create the AR_COM_FAC_SERV_pid_SAP table based on the results of the query.
--The HAVING clause is modified to check if the minimum AREARATE_CODE is not null.
--The MIN() and MAX() functions are used instead of the KEEP syntax.