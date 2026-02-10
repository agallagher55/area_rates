import arcpy

SEASON = "Summer"
YEAR = "2023"

# Copy toolbox
arcpy.management.Copy(
    r"T:\work\giss\tools\Area_Rate_2022_Winter_Overlay_SAP.tbx",
    rf"T:\work\giss\tools\Area_Rate_{YEAR}_{SEASON}_Overlay_SAP.tbx",
    '',
    None
)

# Create geodatabase for archiving features
# T:\work\giss\projects\Area_Rates\Area_Rate_[season]_[year]_SAP.gdb

