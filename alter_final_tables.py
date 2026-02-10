import os

import arcpy

from datetime import datetime


def add_to_feature(add_table, sde_table, tax_year):

    print(f"Importing rows from {add_table} to {sde_table}...")

    table_rows = [row for row in arcpy.da.SearchCursor(add_table, ["PID", "ACCTNO", "ARCODE"])]
    tax_year = datetime.now().year if not tax_year else tax_year
    updated = datetime.now()

    # Append rows to SDE Area_Rates_PID_AAN
    with arcpy.da.InsertCursor(sde_table, ["PID", "AAN", "AREARATE_CODE", "TAXYEAR", "UPDATED"]) as cursor:

        for row in table_rows:
            add_row = [x for x in row] + [tax_year, updated]  # Set Updated Date to now
            cursor.insertRow(add_row)

    del cursor


def update_sde_aggregate_table(sde_workspace, final_tax_tables):
    aggregate_final_table = os.path.join(sde_workspace, "Area_Rates_PID_AAN")

    print(f"\nUpdating SDE aggregate table, '{aggregate_final_table}'")

    print(f"Truncating {aggregate_final_table}...")
    arcpy.TruncateTable_management(aggregate_final_table)

    # Append table data from each table
    for table in final_tax_tables:
        add_to_feature(table, aggregate_final_table, tax_year=2025)

    return aggregate_final_table


def update_service(service_gdb, sde_table):
    print(f"\nUpdating service from {service_gdb}...")

    service_table = os.path.join(service_gdb, "Area_Rates_PID_AAN")

    print("Truncating service gdb table...")
    arcpy.TruncateTable_management(service_table)

    # Append rows
    print("Appending to table...")
    arcpy.Append_management(sde_table, service_table, "NO_TEST")
    print(arcpy.GetMessages())


def copy_previous_year_service_table():
    pass

    
if __name__ == "__main__":
    feature = "SDEADM.Area_Rates_PID_AAN"

    # data = rows_from_template("m052_adds.xlsx")

    DEV_GDB = r"\\msfs06\GISApp\AGS_Dev\fgdbs\web_RO.gdb"

    # QA_GDB = r"\\msfs06\GISApp\AGS_QA\fgdbs\web_RO.gdb"
    QA_GDB = r"\\msfs06\GISApp\\QA\Data\FileGDBs\web_RO.gdb"

    # PROD_GDB = r"\\msfs06\GISApp\AGS_Prod\fgdbs\web_RO.gdb"
    PROD_GDB = r"\\msfs06\GISApp\PROD\Data\FileGDBs\web_RO.gdb"

    DEV_SDE = r"E:\HRM\Scripts\SDE\SQL\dev_RW_sdeadm.sde"
    QA_SDE = r"E:\HRM\Scripts\SDE\SQL\qa_RW_sdeadm.sde"
    PROD_SDE = r"E:\HRM\Scripts\SDE\SQL\Prod\prod_RW_sdeadm.sde"

    for sde_workspace, gdb_service_workspace in [
        # (DEV_SDE, DEV_GDB),
        (QA_SDE, QA_GDB),
        (PROD_SDE, PROD_GDB),
    ]:

        print(datetime.now())

        print(f"\nSDE Workspace: {sde_workspace}\n\tGDB Service Workspace: {gdb_service_workspace}")

        # Remove any AAN in M050 that are already in M052

        skip_tables = [
            'AR_REGTRANS_FINAL_SAP',

            'AR_FIRE_REDUCED_RATE_FINAL_SAP',
            'AR_FIRE_WORSHIP_EXPT_FINAL_SAP',

            'AR_TAXDES_MAX_FINAL_SAP',
            'AR_TAXDES_PRE_FINAL_SAP'
        ]

        with arcpy.EnvManager(workspace=sde_workspace):

            final_tables = sorted(
                [x for x in arcpy.ListTables("*_FINAL_SAP") if x.upper().split("SDEADM.")[1] not in skip_tables]
            )

            final_sde_table = update_sde_aggregate_table(
                sde_workspace=sde_workspace,
                final_tax_tables=final_tables
            )

            if gdb_service_workspace:
                update_service(
                    service_gdb=gdb_service_workspace,
                    sde_table=final_sde_table
                )

            # if workspace.upper().endswith(".GDB"):
            #     feature = feature.replace("SDEADM.", "")
            #
            # m050_aans = [row[0] for row in arcpy.da.SearchCursor(feature, "AAN")]
            
            # add_to_feature(feature, data)

        print(f"\n{datetime.now()}")
