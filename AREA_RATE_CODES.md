# Area Rate Codes

Reference table mapping each `AREARATE_CODE` value used across `Area_Rates_PID_AAN` (and
the various `SAP_*` / `AR_*_FINAL_SAP` tables) to its descriptive name, the feature class
boundary it's spatially derived from, and whether it goes through the standard
`boundary_parcels()` overlay model in `area_rates.py` or is "done differently."

This wasn't previously documented anywhere in this repo as a single readable table - some
individual codes show up unexplained in ad hoc scripts (e.g. `remove_pids.sql` and
`track_pid_41019084.sql` both filter on `AREARATE_CODE LIKE 'M060'` for Transit removals,
without saying what M060 *is*). Source: table shared 2026-08-17, transcribed as-is including
its strikethrough/color annotations.

| Area Rate Code | Descriptive Name | Feature Class Boundary | Notes | Default Model |
|---|---|---|---|---|
| B000 - B080 | Business Improvement Districts | `LND_area_rate_bid` | | YES |
| A000 - A210 | Community Facilities | `LND_area_rate_ComFac_Serv` | A060 and A150 are archived | YES |
| M050 | Fire Protection | `LND_area_rate_fire_protection` | | YES |
| ~~M070~~ | ~~Regional Transit~~ | ~~`LND_area_rate_reg_trans`~~ | *(struck through - deprecated)* | YES |
| **M060** | **Transit (Local Area Transit Rate)** | `LND_area_rate_transit` | | YES |
| M010, M020, M030 | Tax Designation | `ADM_finance_boundaries/ADM_tax_designation`, ~~`ADM_hrm_core`~~ | ~~Omit M020 boundary~~ *(struck through)* | YES |
| M090 | Stormwater ROW | `LND_area_rate_stormwater` | *(green - pending)* financial planning policy -> Dan Friedman | YES |
| M100 - M140 | Commercial (new) | `LND_area_rate_commercial` | *(green - pending)* financial planning policy -> Dan Friedman. Should be okay | YES |
| R000 - R210 | Private Roads | `LND_area_rate_Priv_Road` | | **NO** |
| A220 | Active Transit | `LND_area_rate_active_trans` | | YES |

## Key takeaway for the transit rate report

**Local Area Transit Rate = code `M060`**, boundary `LND_area_rate_transit`. This is the
code to filter `Area_Rates_PID_AAN.AREARATE_CODE` on directly - see
`local_transit_rate_listing.sql`. `M070` (Regional Transit) is a separate, deprecated
code/boundary - don't confuse the two.

## Reading the annotations

- **Strikethrough** = deprecated/no longer used (Regional Transit's code, boundary, and the
  old `ADM_hrm_core` tax designation boundary; the "Omit M020 boundary" note is itself struck
  through, i.e. that caveat no longer applies).
- **Green text** = newer/tentative area rates still pending confirmation from financial
  planning policy (Dan Friedman) as of when this table was made.
- **Default Model = NO** (Private Roads only) = does *not* go through `boundary_parcels()`'s
  standard Identity/Frequency overlay; handled by the bespoke `private_roads()` function in
  `area_rates.py` instead (see its docstring: `Private Roads: ... --> Done differently`).

## Open questions from cross-checking this against the code

1. **`area_rates.py`'s docstring (lines 10, 132) still lists Regional Transit
   (`SDEADM.LND_area_rate_reg_trans`) as an active type.** It isn't in `area_rates.ini`'s
   `[AreaRates] features` list, and its SQL already lives under `SQL/archive/regtrans/` - so
   the code already treats it as retired, matching this table's strikethrough. The docstring
   comment is just stale and could be cleaned up.
2. **Fire Protection (M050) is marked `Default Model: YES` here**, but `area_rates.py`'s
   docstring says `Fire Protection: SDEADM.LND_area_rate_fire_protection --> Done
   differently` (grouped with Private Roads). One of these is out of date - worth confirming
   which, since it affects whether Fire's `SAP_FIRE_PROTECTION` table is trustworthy as
   produced by the standard overlay.
3. **Private Roads is `Default Model: NO`**, consistent with `private_roads()` existing as a
   special case - but `area_rates.py`'s `__main__` loop calls `private_roads()` for
   `LND_area_rate_Priv_Road` and then *also* falls through to `boundary_parcels()` on the same
   feature afterward (the `if` branch doesn't `continue`/skip). Worth checking whether that
   second call is intentional (a redundant/unused `SAP_Priv_Road` table) or a bug.
