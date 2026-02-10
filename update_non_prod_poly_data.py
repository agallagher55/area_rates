"""
    Synchronize selected area rate polygons between SDE environments.

    This script connects to a reference SDE geodatabase and a target SDE
    geodatabase. It clears all rows from each polygon feature class in the
    target and appends the corresponding features from the reference.
    By default, predefined area rate layers and parcel polygons are updated.
"""

import logging
import os
import arcpy

from datetime import datetime

QA_SDE = r"E:\HRM\Scripts\SDE\SQL\qa_RW_sdeadm.sde"
PROD_SDE = r"E:\HRM\Scripts\SDE\SQL\Prod\prod_RW_sdeadm.sde"
YEAR = datetime.now().year

def get_default_features(year):
    """Return area rate features with an optional year for transit."""

    return {
        "LINNS_PIDRELATE": {},
        "LINNS_PIDAANTAX": dict(),

        "LND_area_rate_bid": {},
        "LND_area_rate_ComFac_Serv": {},
        "LND_area_rate_transit": f"DESCRIP LIKE '{year} Local Transit'",
        "LND_area_rate_active_trans": {},
        "LND_area_rate_fire_protection": {},
        "ADM_finance_boundaries//ADM_tax_designation": {},
        "LND_area_rate_commercial": {},
        "LND_area_rate_stormwater": {},
        "LND_area_rate_Priv_Road": {},
    }


def update_polygons(rate_boundaries, update_sde, reference_sde, logger):
    print(f"\nUpdating polygons in '{update_sde}' with data FROM: '{reference_sde}'...")

    arcpy.env.workspace = update_sde

    polygons = list(rate_boundaries.keys()) + [
        "SDEADM.LND_parcels//SDEADM.LND_parcel_polygon"
    ]

    for poly in polygons:
        logger.info(f"{poly}")

        update_poly = os.path.join(update_sde, poly)
        reference_poly = os.path.join(reference_sde, poly)

        try:
            arcpy.DeleteRows_management(update_poly)
            arcpy.Append_management(reference_poly, update_poly, "NO_TEST")
            logger.info(arcpy.GetMessages())

        except arcpy.ExecuteError:
            logger.error(arcpy.GetMessages(2))
            continue

        except Exception as err:
            logger.exception(f"Unexpected error processing {poly}: {err}")
            continue


if __name__ == "__main__":

    logging.basicConfig(
        filename=None,
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    logger = logging.getLogger(__name__)

    features = get_default_features(year='2025')
    update_polygons(
        features,
        update_sde=QA_SDE,
        reference_sde=PROD_SDE,
        logger=logger
    )
