-- ============================================================================
-- Local Area Transit Rate - Current Listing
--
-- Requested by: Vicki Robertson (Director, Revenue) - email 2026-08-15,
-- "Local Area Transit Rate - Report from pre-prod". Revenue is seeing
-- differences "both ways" for the local area transit rate and wants a
-- listing to help work out what's a real route change vs. a measurement
-- artifact (see known_issues.md #1 and #2 for the two documented candidates:
-- the provincial PID/AAN timing gap, and overlapping Area Rate boundary
-- polygons dropping/reassigning a code).
--
-- Local Area Transit Rate = AREARATE_CODE 'M060' (see AREA_RATE_CODES.md).
-- Don't confuse with M070 (Regional Transit, deprecated) - a different
-- code/boundary entirely.
--
-- ArcGIS Pro: this is a single SELECT, so it works either as a Query Layer
-- (Add Data -> Query Layer -> New Query Layer), or as just the WHERE clause
-- below in Select By Attributes on an already-open Area_Rates_PID_AAN table:
--   AREARATE_CODE = 'M060'
-- ============================================================================

SELECT
    PID,
    AAN AS ACCTNO,
    AREARATE_CODE,
    TAXYEAR,
    UPDATED
FROM SDEADM.Area_Rates_PID_AAN
WHERE AREARATE_CODE = 'M060'
ORDER BY PID;
