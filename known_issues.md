# Known Issues

## 1. Missing AANs Due to Provincial Data Timing Gap

The area rate process relies on two datasets from the Province of Nova Scotia: the parcel fabric (property boundaries) and a few LINNS tables (including one which link PIDs to AANs). When properties are reconsolidated or subdivided, the updates to these datasets likely happen at different times — the LINNS tables are updated before the parcel boundaries.

This creates a timing gap. For example, PID 40194946 (AAN 05626617):

- In **December**, this PID had a valid AAN and existed in the parcel fabric, so it appeared in last year's report.
- By **January**, the LINNS table had already been updated — the old PID was disconnected from its AAN (`TAXCONFIRM` set to `F`) in preparation for a new PID (41556374). However, the parcel fabric still contained the old boundaries and did not yet include the new PID's geometry.

As a result, during this year's processing, the spatial query finds the old parcel but the PID-to-AAN join returns no match, so the AAN drops out of the report. The new PID that will carry this AAN forward doesn't have a parcel boundary yet, so it can't be picked up spatially either.

This is a transient issue — once the Province updates the parcel fabric to reflect the new boundaries, these AANs will reappear in subsequent reports under their new PIDs. Alternatively, we could take a snapshot of the LINNS tables and then wait a couple months before using the parcel fabric. In summary, this is a consequence of the two provincial datasets being out of sync during property reconsolidations.

### Visuals

- The current parcel fabric, updated in February, for the parcels of interest, are in dotted black lines.
- The parcel fabric, as it looked in January, is in red.
- The LINNS PID-AAN lookup table from December is on the left and from January is on the right.
<img width="745" height="547" alt="image" src="https://github.com/user-attachments/assets/dd102898-4530-4c2f-9801-f93025c08644" />

## 2. Overlapping Area Rate Boundary Polygons

One of the area rate boundary feature classes likely contains overlapping polygons. When a parcel falls within an overlap, the spatial overlay (Identity) assigns multiple area rate codes to the same PID. The SQL then selects only one of the rate codes (the record with the largest overlap area), which means the other valid rate code is silently dropped.

This can result in a property being assigned to the wrong area rate or missing from a rate it should belong to.

