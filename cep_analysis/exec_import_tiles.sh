#!/bin/bash
# IMPORT 648 RASTER TILES IN GRASS

echo "-----------------------------------------------------------------------------------"
echo "--- Script $(basename "$0") started at $(date)"
echo "-----------------------------------------------------------------------------------"

startdate=`date +%s`

# READ VARIABLES FROM CONFIGURATION FILE
SERVICEDIR="/globes/processing_current/servicefiles"
source ${SERVICEDIR}/cep_processing.conf

MAPSET="ECO26"
prefix="ecoreg_"
MAPSET_PATH=${DATABASE}/${LOCATION_LL}/${MAPSET}
RASTER_TILES_PATH="/spatial_data/Derived_Datasets/RASTER/ECOREGIONS_2026/tiles"

# LOCAL VARIABLES
grass ${PERMANENT_MAPSET_LL} --exec g.mapset -c ${MAPSET}

# Import individual till tiles with r.external
for t in {1..648}
do
	./slave_import_tiles.sh ${t} ${MAPSET_PATH} ${RASTER_TILES_PATH} ${prefix}
done

wait

# Remove dynamic scripts
echo dyn/*.sh |xargs rm -f

enddate=`date +%s`
runtime=$(((enddate-startdate) / 60))

echo "-----------------------------------------------------------------------------------"
echo "Script $(basename "$0") ended at $(date)"
echo "-----------------------------------------------------------------------------------"
echo "RASTER tiles imported in "${runtime}" minutes"
echo "-----------------------------------------------------------------------------------"

exit

