"""
Copies this repo's SQL scripts to a new dated folder under T:\\work\\giss\\tools\\Area_Rates
so they can be run against SQL Server for this season, matching how past seasons'
scripts were laid out on the T: drive.

This copy step may not be needed going forward if we start running the scripts
directly from the local repo folder instead - kept for now to match the existing
workflow in steps.txt.

Update YEAR and SEASON below before running.
"""

import os
import shutil

YEAR = "2026"
SEASON = "Summer"

REPO_SQL_DIR = os.path.join(os.path.dirname(__file__), "SQL")
DEST_ROOT = r"T:\work\giss\tools\Area_Rates"


def copy_sql_scripts(year=YEAR, season=SEASON):
    """
    Copy the repo's SQL scripts into a new "v{year}_{season} - SAP\\SQL Server"
    folder under DEST_ROOT.

    :param year:
    :param season:
    :return: path to the copied "SQL Server" folder
    """

    dest_folder = os.path.join(DEST_ROOT, f"v{year}_{season} - SAP", "SQL Server")

    if os.path.exists(dest_folder):
        raise FileExistsError(f"Destination already exists, remove it or bump YEAR/SEASON: {dest_folder}")

    print(f"Copying SQL scripts from {REPO_SQL_DIR} to {dest_folder}...")
    shutil.copytree(
        REPO_SQL_DIR,
        dest_folder,
        ignore=shutil.ignore_patterns("*.py", "*.txt", "archive"),
    )
    print("Done.")

    return dest_folder


if __name__ == "__main__":
    copy_sql_scripts()
