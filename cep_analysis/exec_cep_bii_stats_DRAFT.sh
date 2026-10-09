#!/bin/bash
##COMPUTE STATISTICS ON CEP AND A USER DEFINED CONTINUOUS RASTER

echo "-----------------------------------------------------------------------------------"
echo "--- Script $(basename "$0") started at $(date)"
echo "-----------------------------------------------------------------------------------"

startdate=`date +%s`

# READ VARIABLES FROM CONFIGURATION FILE
SERVICEDIR="/globes/processing_current/servicefiles"
source ${SERVICEDIR}/cep_processing.conf

## OVERRIDE NCORES DEFINED IN CONF FILE
NCORES=48

########################################################################################################
# DEFINE CONTINUOUS RASTER (NAME OF GRASS LAYER) AND MAPSET TO BE ANALYZED WITH R.UNIVAR
IN_RASTER="bii_2025"
IN_RASTER_MAPSET="PERMANENT"
########################################################################################################

## Derived variables
LOCATION_LL_PATH=${DATABASE}/${LOCATION_LL}
PERMANENT_LL_MAPSET=${DATABASE}/${LOCATION_LL}"/PERMANENT"
OUTCSV_ROOT="cep_"${IN_RASTER}
FINALCSV="r_univar_"${OUTCSV_ROOT}"_${wdpadate}"

## PART I: COMPUTATION OF STATISTICS

echo "Input raster: "${IN_RASTER}@${IN_RASTER_MAPSET}
echo "now running r.univar in parallel on CEP tiles and "${IN_RASTER}" using "${NCORES}" threads"

for eid in {109..648}
do	
	TMP_MAPSET=qwe_${eid}
	TMP_MAPSET_PATH=${LOCATION_LL_PATH}/${TMP_MAPSET}
	OUTCSV=${OUTCSV_ROOT}_${eid}
	grass ${PERMANENT_LL_MAPSET} -f --exec g.mapset --o --q -c ${TMP_MAPSET}
	wait
	echo "./slave_cep_conraster_stats.sh ${eid} ${TMP_MAPSET_PATH} ${RESULTSPATH_TMP} ${IN_RASTER}@${IN_RASTER_MAPSET} ${OUTCSV} ${CEP_MAPSET}"
done | parallel -j ${NCORES}

wait

## PART II: AGGREGATE CSV TILES

rm -f ${RESULTSPATH}/${FINALCSV}.csv
cat ${RESULTSPATH_TMP}/${OUTCSV_ROOT}_*.csv >> ${RESULTSPATH}/${FINALCSV}.csv

wait

## PART III : CREATE PG TABLE AND IMPORT FINAL CSV IN POSTGIS
echo " "
echo "Now importing csv table in Postgis..."
echo " "

psql ${dbpar2} -t -v vNAME=${FINALCSV} -v vSCHEMA=delli -f ./sql/create_table_runivar.sql
psql ${dbpar2} -t -c "\copy delli.${FINALCSV} FROM '${RESULTSPATH}/${FINALCSV}.csv' delimiter '|' csv"

wait

## PART IV : CLEAN UP (delete mapsets and intermediate files)
rm -rf ${LOCATION_LL_PATH}/qwe_*
rm -f ${RESULTSPATH_TMP}/${OUTCSV_ROOT}_*.csv
echo dyn/*.sh |xargs rm -f

enddate=`date +%s`
runtime=$(((enddate-startdate) / 60))

echo "---------------------------------------------------------------------------------------"
echo "Script $(basename "$0") ended at $(date)"
echo "---------------------------------------------------------------------------------------"
echo "Stats on CEP and ${IN_RASTER} computed in "${runtime}" minutes using "${NCORES}" cores "
echo "---------------------------------------------------------------------------------------"
exit
