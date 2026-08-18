# Area Rates

*GIS Process Documentation – Corporate Tax Area Rates*
Halifax Regional Municipality | Information, Communication & Technology – GIS

---

## 1. Overview

This document consolidates the GIS process notes, resources, and reference material used to run the annual Area Rate cycle for Halifax Regional Municipality (HRM). Area rates are supplementary local taxes applied to properties within defined boundaries (fire protection, transit, business improvement districts, community facilities, stormwater, private roads, and related designations) and are recovered through the tax billing process.

The cycle is run annually by GIS staff in coordination with Finance/Revenue and the relevant business units for each area rate type, and results feed the interim and final tax bills.

### 1.1 Key Dates

- Interim Tax Bill – late December / early January
- Full geo-audit – late June / early July
- QA / test rate call – mid-July (target: July 17)

## 2. Resources

- **How-to Guide:** `H:\GIS\Documentation\Data Loads\Tax Area Rates\GIS Tax Area Rate Process SAP.docx`
- **Overlay Models:** `T:\work\giss\tools`
- **SQL Scripts:** `T:\work\giss\tools\Area_Rates`
- **Repository:** [github.com/agallagher55/area_rates](https://github.com/agallagher55/area_rates)
- **Parcel search service:** [AGS_Parcel_WGS84 / MapServer / 1](https://gisapp-int.halifax.ca/hrm/rest/services/HRM/AGS_Parcel_WGS84/MapServer/1)
  *Published from: WEB RO – Parcel Owner (LND_parcel_owner), Parcel Assessment (LND_finance_hansen_point)*

### 2.1 GIS Specialists for Area Rate Boundaries

- Fire – Robbie Evans
- Transit – Tristan Marvin

### 2.2 Map Documents

Base path: `E:\HRM\Services\Map_Documents\AreaRates`

- **Q26 (QA):** `\\hrm.halifax.ca\fs\GISApp\QA\Data\FileGDBs\web_RO.gdb`
- **P26 (Prod):** `\\hrm.halifax.ca\fs\GISApp\PROD\Data\FileGDBs\web_RO.gdb`

## 3. Preparation

- [ ] Confirm ICT has updated all area rate feature classes, including the fire and transit area rate boundaries, and that updates have been posted to default before work begins.
- [ ] Create a new toolbox for the current year in `T:\work\giss\tools`, copied from the previous year, and update the models for any area rate code changes.

## 4. Area Rate Codes

The table below lists each area rate code group, its descriptive name, source feature class, and whether it participates in the default overlay model.

| Area Rate Code | Descriptive Name | Feature Class Boundary | Notes | Default Model |
|---|---|---|---|---|
| B000 – B080 | Business Improvement Districts | LND_area_rate_bid | | Yes |
| A000 – A210 | Community Facilities | LND_area_rate_ComFac_Serv | A060 and A150 are archived | Yes |
| M050 | Fire Protection | LND_area_rate_fire_protection | | Yes |
| M070 (retired) | Regional Transit | LND_area_rate_reg_trans | Code retired | Yes |
| M060 | Transit | LND_area_rate_transit | | Yes |
| M010, M020, M030 | Tax Designation | ADM_finance_boundaries / ADM_tax_designation | Omit M020 boundary; ADM_hrm_core no longer used | Yes |
| M090 | Stormwater ROW | LND_area_rate_stormwater | Financial planning policy contact: Dan Friedman | Yes |
| M100 – M140 | Commercial (new) | LND_area_rate_commercial | Financial planning policy contact: Dan Friedman | Yes |
| R000 – R210 | Private Roads | LND_area_rate_Priv_Road | | No |
| A220 | Active Transit | LND_area_rate_active_trans | | Yes |

### 4.1 Commercial (New)

Feature class: `LND_area_rate_commercial` – 5 zones plus urban / suburban / rural designation:

1. Rural Area – SDEADM.ADM_tax_designation
2. Community Area (outside CDD)
3. Downtown / Community Area
4. Industrial Park Area – SDEADM.LND_business_park
5. Business Park Area – SDEADM.LND_business_park

Working files:

- `T:\work\giss\monthly\202210oct\gallaga\Area Rates\area_rates\Default.gdb\LND_area_rate_commercial_new`
- `T:\work\giss\monthly\202210oct\gallaga\Area Rates\area_rates\Default.tbx\model`

Input features: LND_business_park (filtered); ADM_finance_boundaries / ADM_tax_designation (filtered); CDD_Boundary_Layer.

### 4.2 Stormwater

- Source: ADM_hrm_core
- Filter by boundary date

## 5. Overlay Analysis

The overlay analysis moves each area rate boundary feature class through three stages: Models, SQL Scripts, and QA Process, described below.

### 5.1 Models

Runs an intersect analysis of each area rate polygon over parcels, producing a `SAP_{area rate}` table for the SQL scripts in SDE.

Source: `T:\work\giss\tools\Area_Rate_{year}_{season}_Overlay_SAP.tbx`

**Inputs:**

- Area Rate feature
- LND_parcel_polygon

**Outputs:**

- SDE table (`SAP_{area rate}`) with PID, frequency of that PID, the area rate it falls within, and total area
- Geometry feature in the local workspace as `{area rate name}_identity`

- [ ] Run models with up-to-date Area Rate boundaries and models.

### 5.2 SQL Scripts

Source: `T:\work\giss\tools\Area_Rates\{year}_{season}_SAP`

Creates tables in SDE (`AR_{Area Rate}_FINAL_SAP`).

1. PID, Area Rate, largest area, filtering out non-null areas – Input: `SAP_AREA_RATE_{area rate}`; Output: `AR_{area rate}_PID_SAP`; Fields: PID, ARCODE, AREA
2. Get AAN via join with LINNS_PIDAANTAX – Inputs: `AR_{area rate}_pid_SAP`, LINNS_PIDAANTAX; Output: `AR_{area rate}_AAN_SAP`; Fields: AAN, PID, ARCODE
3. Get condo PIDs via join with LINNS_PIDRELATE – Inputs: `AR_{area rate}_PID_SAP`, LINNS_PIDRELATE; Output: `AR_{area_rate}_CONDO_in_SAP`; Fields: PID, PIDRELATE, RELNAME, ARCODE
4. Get associated AANs for condo PIDs, removing any associated null AANs – Inputs: `AR_{area_rate}_CONDO_in_SAP`, LINNS_PIDAANTAX; Output: `AR_{area_rate}_CONDO_AAN_SAP`; Fields: AAN, PIDRELATE, PID, ARCODE
5. Populate table with PID, AAN, ARCODE from the AAN intermediate tables – Inputs: `AR_{area rate}_AAN_SAP`, `AR_COM_{area rate}_CONDO_AAN_SAP`; Output: `AR_{area rate}_final_SAP` (final feature); Fields: PID, AAN, ARCODE
6. Drop intermediate tables – SAP_COM_NEW; AR_COM_NEW_pid_SAP; AR_COM_NEW_AAN_SAP; AR_COM_NEW_CONDO_in_SAP; AR_COM_NEW_CONDO_AAN_SAP

*Run steps from a command prompt: cd into the script directory, launch sqlplus, connect as `sdeadm@'msgisorap201:1504/GISRWP01'`, then run `@script_name.sql` for each script.*

- [ ] Make a copy of the previous year's working folder for this year's analysis.
- [ ] Modify the SQL scripts to account for any area rate code changes.
- [ ] Run the SQL batch scripts.
- [ ] Export each `AR_FINAL_[area_rate_name]` table to a QC geodatabase.

### 5.3 QA Process

Features involved: LND_finance_hansen_point (A), LND_parcel_polygon (B), `AR_{area rate}_final_SAP` (C).

1. Export the `AR_{area rate}_final_SAP` feature to a geodatabase (this grants an OID field needed for joining).
2. Join LND_finance_hansen_point to AR_AreaRate_FINAL_SAP on the AAN field – keep only matching records, export the data, then un-join LND_finance_hansen_point.
3. Observe points outside the Area Rate boundary; check whether a point with the same AAN exists within the area rate. Symbolize by ARCODE.
4. Merge the AREA_RATES_FINAL_SAP features into the final, aggregated feature: AREA_RATES_PID_AAN.

*Pro project set-up: LND_parcel_polygon (labelled by PID), the Area Rate boundaries, the AreaRate_final_SAP table, and PID_AAN_TAX / PID_RELATE for reference.*

**QC verification process:**

1. Add the joined point layer to the map.
2. Select by location to get the points that don't intersect the Area Rate boundary.
3. Export the points that don't intersect the boundary.
4. For points that don't intersect the boundary, confirm the AAN owns a PID that does intersect the Area Rate.
5. Check PID_AAN_TAX for other PIDs owned by that AAN, and whether any of those fall within the Area Rate boundary.

### 5.4 New Commercial Area Rate

Process: `T:\work\giss\monthly\202210oct\gallaga\Area Rates\area_rates\Default.tbx\model`

**Input features:**

- LND_business_park – filtered
- ADM_finance_boundaries / ADM_tax_designation – filtered
- CDD_Boundary_Layer

**Output feature:**

`T:\work\giss\monthly\202210oct\gallaga\Area Rates\area_rates\Default.gdb\LND_area_rate_commercial_new`

**New codes:**

1. M090 – Stormwater (ADM_hrm_core, filtered by date)
2. M100 – Business Park Area
3. M110 – Industrial Park Area
4. M120 – Downtown / Community Area
5. M130 – Community Area (outside CDD)
6. M140 – Rural Area

## 6. Post-Processing

- [ ] Truncate the Area_Rates_PID_AAN table in RW.
  - [ ] Append the xxx_Final_SAP tables into Area_Rates_PID_AAN (PID = PID, ACCTNO = AAN, ARCODE = AREARATE_CODE).

The append step loads each finalized area rate table into the consolidated `SDEADM.Area_Rates_PID_AAN` target dataset. Source (input) tables:

- SDEADM.AR_BID_FINAL_SAP
- SDEADM.AR_COM_FAC_SERV_FINAL_SAP
- SDEADM.AR_FIRE_FINAL_SAP
- SDEADM.AR_FIRE_REDUCED_RATE_FINAL_SAP
- SDEADM.AR_PRIVRD_FINAL_SAP
- SDEADM.AR_REGTRANS_FINAL_SAP
- SDEADM.AR_TAXDES_FINAL_SAP
- SDEADM.AR_TRANSIT_FINAL_SAP

- [ ] Calculate the TAXYEAR and UPDATED fields.
- [ ] Truncate Area_Rates_PID_AAN in `\\msfs06\gisapp\AGS_PROD107\fgdbs\web_RO.gdb`.
  - [ ] Append data from RW.
  - [ ] Check the map service for the update.

**Service:** [Area_Rate_Overlay_Result / MapServer](https://gisappa-int.halifax.ca:6443/arcgis/rest/services/Area_Rates/Area_Rate_Overlay_Result/MapServer)

- [ ] Update metadata.
- [ ] Copy data to `T:\work\giss\projects\Area_Rates`.

### 6.1 Reporting

Standard question from Finance/Revenue: counts of AANs / PIDs embedded within each boundary (area rate code).

## 7. Appendix A – Fire Protection Area Rate Data Maintenance & Support Plan

*Summarized from the corporate Data Maintenance & Support Plan for the Fire Protection area rate (ICT# 0043193), forwarded by Robbie Evans (GIS Specialist) on May 8, 2023 to Halifax Fire Services, Revenue, and FICT for review and sign-off, with Halifax Water and FICT copied for reference.*

### 7.1 Document Control

| Field | Value |
|---|---|
| Document ID | ICT# 0043193 |
| Document Owner | Ken Lenihan |
| Last Saved Date | March 24, 2023 |
| File Name | `R:\ICT\ICT BIDS\Data Maintenance Agreements\Area Rates\Fire Protection.docx` |

**Document history:**

| Version | Issue Date | Author | Changes |
|---|---|---|---|
| 1.0 | Dec. 23, 2014 | Ken Lenihan | For Approval |
| 1.0.1 | February 25, 2015 | Ken Lenihan | Approved |
| 1.0.2 | October 11, 2017 | Ken Lenihan | Amended from meeting with stakeholders |
| 1.0.3 | October 12, 2017 | Ken Lenihan | Approved |
| 1.0.4 | April 26, 2018 | Ken Lenihan | Amended Halifax Water contact information |
| 1.0.5 | April 27, 2020 | Ken Lenihan | Amended due to change in process with Halifax Water |
| 1.0.6 | January 12, 2023 | Robbie Evans | Amended again due to change in process with Halifax Water |

**Approvals** – the undersigned confirm the acceptability of the document in the management of the data:

| Role | Name / Title |
|---|---|
| Business Owner | Renee Towns, Director Revenue, Finance |
| Project Sponsor | Renee Towns, Director Revenue, Finance |
| Data Architect | Qingshuang Jiang, Data Architect, FICT |
| Data Manager | Ken Lenihan, GIS Manager, FICT |
| Halifax Water Manager | Harold MacNeil, Manager Engineering Information |
| Halifax Fire Services | Mark Burgess, Divisional Chief, Communications & Technology |

### 7.2 Project Overview

Finance & Information, Communication, Technology (FICT) is responsible for producing the yearly tax bills. Historically, additions and decommissioned fire hydrants are received from Halifax Regional Fire Services, and the Network Analyst tools/models are run on that data. The output determines which properties are subject to the fire protection rate on their tax bills.

All Fire Protection Area Rate data comes from HRM's Corporate GIS database and has no restrictions on internal use. Many of the underlying layers are also published to the public through the Municipality's Open Data Catalogue (halifax.ca/opendata).

### 7.3 Points of Contact

| Point of Contact | Name / Group | Email |
|---|---|---|
| Development / Maintenance / Operations | GIS Specialist – Robbie Evans, ICT GIS | evansr@halifax.ca |
| Business Application Support (routines) | GIS Systems Analyst – Alex Gallagher, ICT GIS | gallaga@halifax.ca |
| Business Unit Support | Divisional Chief, Communication & Technology – Mark Burgess, Halifax Fire Services | burgesm@halifax.ca |
| Halifax Water – hydrant data questions | HW GIS Technical Group | GISHelpdesk@halifaxwater.ca |
| Halifax Water – hydrant data requests | HW GIS Products | GISProducts@halifaxwater.ca |
| Business Unit Support | Director Revenue – Renee Towns, Revenue | townsr@halifax.ca |

### 7.4 Data Environment

The data exists in the Corporate GIS as the polygon feature class `LND_area_rate_fire_protection`, derived from HWADM.AST_water_hydrant, TRN_street_network, and LND_parcel_polygon. It is updated by GIS staff annually and may change each June through the addition, movement, or decommissioning of hydrants, or through subdivision activity.

Finance/Revenue initiates the annual project with GIS no later than April 1. GIS requests hydrant data from Halifax Water no later than May 15, targeting delivery by June 1 to begin the analysis. Geodatabase history is enabled, so prior states of the data are retained and retrievable.

Editing is restricted to designated GIS staff; access changes are requested through the ICT Service Desk and actioned by the GIS Systems Analyst. All GIS users with access can view and use the data, and it is also published through HRM Open Data.

### 7.5 Data Maintenance Process

Halifax Water supplies updated hydrant data annually, triggered by an HRM (GIS) request to the GISProducts@halifaxwater.ca help desk. By the beginning of June, the GIS Specialist applies the appropriate queries in coordination with Halifax Fire Services and runs the Network Analyst tools/models. The GIS Systems Analyst performs final QC and the spatial overlay analysis. Once all parties approve, results are posted to production and published to Halifax Open Data.

**Role of business units:**

- Halifax Water – supplies hydrants and verifies the Fire Protection Flag field is populated.
- GIS & Halifax Fire Services – verify the Fire Protection Flag field was correctly queried before input to the Network Analyst tools; Finance approves any resulting boundary changes.
- GIS Specialist (BIDS) – runs the analysis tools, flags potential additions or deletions for review, applies approved boundary changes, and publishes to Open Data.
- ICT Service Desk – logs requests concerning the Fire Protection data to the GIS & Data queue; the Corporate Call Centre logs taxation/billing inquiries to Finance Revenue.

Service level: the Fire Protection Area Rate boundary is edited and passed along for review within two weeks (10 business days) of receiving hydrant data and Fire Protection Flag verification.

### 7.6 Data Integrity & Audits

A data integrity / quality audit is carried out annually, in May, by the Business Unit Support designate, prior to delivery of the data to the GIS Specialist. The audit comments on attribute quality and on changes to the data over time. Audit contacts are Robbie Evans (GIS Specialist) and Renee Towns (Director, Revenue).

Availability depends on the corporate GIS system and, once published, on the Open Data site; there is no alternate access path if the corporate GIS system is unavailable. System maintenance is scheduled outside operational hours where possible.

### 7.7 Notification & Troubleshooting

The Open Data team is notified once the Network Analyst run is complete and the LND_area_rate_fire_protection feature class has been created.

**For issues:**

- ICT Service Desk – log a ServiceNow incident, 490-4444, ictsd@halifax.ca (see also ArcGIS Desktop Help / Resource Centre)
- Corporate Call Centre – 311, contacthrm@halifax.ca

### 7.8 Overview of Responsibilities

| Role | Responsibilities |
|---|---|
| GIS Specialist | Create, update, and delete features from the Fire Protection Area Rate boundary. Address enquiries about Fire Protection Area Rate data and complete related service requests. |
| GIS Systems Analyst | Implement updates or changes to corporate data models. Make changes to the analysis models. |
| Business Unit Support Point of Contact | Deliver the dataset upon request. Address questions received on fire protection status. |
| ICT Service Desk | Log requests related to the Fire Protection Area Rate data and assign them to the appropriate queue. |
| Corporate Call Centre | Log inquiries related to taxation / billing and pass them along to the Finance Revenue Division. |

## 8. Review Notes / Open Questions

Flagged while adding this document to the repo — none of these were changed in the text above, they're left for whoever maintains this doc to resolve:

1. **M070 retirement vs. post-processing append list.** Section 4 marks M070 (Regional Transit) as retired, but section 6's append list still includes `SDEADM.AR_REGTRANS_FINAL_SAP` as a source table. Confirm whether that table is still populated/appended each cycle, or whether the post-processing list is stale from before the code was retired.

2. **Naming inconsistency in the SQL Scripts steps (5.2).** Step 5 references an input `AR_COM_{area rate}_CONDO_AAN_SAP`, but step 4's output is `AR_{area_rate}_CONDO_AAN_SAP` — no `COM_` prefix. Step 6's cleanup list also hardcodes literal `COM_NEW` table names (`SAP_COM_NEW`, `AR_COM_NEW_pid_SAP`, etc.) rather than following the generic `{area rate}` placeholder used elsewhere in the section. Worth deciding whether this was a copy/paste artifact from the Commercial (COM) scripts specifically, and either generalizing the placeholders or making clear these are one worked example.

3. **Fire Protection contact/approval info may drift.** Section 7's names, emails, and document-control table are dated 2023 and earlier. If this becomes the canonical workflow doc, consider adding a "last verified" date so stale contacts are easier to catch.

4. **"QA / test rate call" (1.1) is unclear.** Not obvious from the doc alone whether this is a meeting, a script run, or a deadline for something. A one-line clarification would help a new reader.

No existing document in this repo covers the same ground — `steps.txt`, `known_issues.md`, `DEBUG_GUIDE.md`, `PID_TRACKING_CHEATSHEET.md`, `AAN_to_PID_Logic_Flow.md`, `AAN_to_Parcel_Cheatsheet.md`, and `analysis_taxdes_missing_properties.md` are all code/debugging-focused technical references, not a business-process overview of the annual cycle. This file is intended to be the single reference for that.
