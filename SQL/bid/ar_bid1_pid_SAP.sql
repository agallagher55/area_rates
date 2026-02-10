USE [GISRW01];
GO

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

SELECT * FROM [SDEADM].[AR_bid_pid_SAP];

--The inner subquery selects the columns pid, AREARATE_CODE, and shape_area from SAP_bid.
--It also uses the ROW_NUMBER() function to assign a sequential number to each row within each group of pid,
--ordered by shape_area in descending order. The outer query then filters the results by
--selecting only the rows where rn (the row number) is equal to 1.
--This effectively selects the rows with the highest shape_area for each unique pid value.
