"""
Runs a Run_xxx.sql script directly against SQL Server through a live ArcSDE
connection, using arcpy.ArcSDESQLExecute - no need to copy files to the T:
drive or open them in SSMS first.

Prototype: only wired up to run the 'bid' folder's Run_Bid.sql so the
approach can be verified before converting the rest of the SQL folders.
"""

import os
import re

import arcpy

SDE_WORKSPACE = r"E:\HRM\Scripts\SDE\SQL\qa_RW_sdeadm.sde"

SQL_DIR = os.path.join(os.path.dirname(__file__), "SQL")

# GO is a batch separator SSMS/sqlcmd understand, but it isn't valid T-SQL, so
# a script has to be split on it before sending batches through ArcSDESQLExecute.
GO_RE = re.compile(r"^\s*GO\s*$", re.IGNORECASE | re.MULTILINE)

# The ArcSDE connection already targets a specific database/version, so USE
# statements (also SSMS-only in this context) are stripped rather than sent.
USE_RE = re.compile(r"^\s*USE\s+.*?;?\s*$", re.IGNORECASE | re.MULTILINE)

LINE_COMMENT_RE = re.compile(r"--.*$", re.MULTILINE)
BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.DOTALL)


def _is_comment_only(batch):
    stripped = BLOCK_COMMENT_RE.sub("", batch)
    stripped = LINE_COMMENT_RE.sub("", stripped)
    return not stripped.strip()


def load_batches(sql_path):
    """
    Read a Run_xxx.sql file and split it into the individual batches to send
    to ArcSDESQLExecute.execute() one at a time. Batches that are only
    comments (e.g. a file header before the first GO) are dropped since
    they're a no-op round trip.

    :param sql_path: path to a Run_xxx.sql file
    :return: list of non-empty SQL batch strings, in file order
    """

    with open(sql_path, "r") as f:
        text = f.read()

    text = USE_RE.sub("", text)

    batches = [batch.strip() for batch in GO_RE.split(text)]
    return [batch for batch in batches if batch and not _is_comment_only(batch)]


def run_sql_file(sql_path, sde_workspace=SDE_WORKSPACE):
    """
    Execute every batch in a Run_xxx.sql file against sde_workspace, in order.

    :param sql_path: path to a Run_xxx.sql file
    :param sde_workspace: path to an .sde connection file
    """

    egdb_conn = arcpy.ArcSDESQLExecute(sde_workspace)
    batches = load_batches(sql_path)

    print(f"Running {sql_path} ({len(batches)} batch(es)) against {sde_workspace}...")

    for i, batch in enumerate(batches, start=1):
        print(f"\tBatch {i}/{len(batches)}...")

        try:
            result = egdb_conn.execute(batch)
        except arcpy.ExecuteError:
            print(arcpy.GetMessages(2))
            raise

        if isinstance(result, list):
            print(f"\t\t{len(result)} row(s) returned")
        elif result is False:
            print(f"\t\tBatch reported failure, see above for details")

    print("Done.")


if __name__ == "__main__":
    run_sql_file(os.path.join(SQL_DIR, "bid", "Run_Bid.sql"))
