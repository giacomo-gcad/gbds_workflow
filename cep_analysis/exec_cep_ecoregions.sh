##!/bin/bash
##COMPUTE STATISTICS ON CEP AND A USER DEFINED CATEGORICAL RASTER

echo "-----------------------------------------------------------------------------------"
echo "--- Script $(basename "$0") started at $(date)"
echo "-----------------------------------------------------------------------------------"

startdate=`date +%s`

# READ VARIABLES FROM CONFIGURATION FILE
SERVICEDIR="/globes/processing_current/servicefiles"
source ${SERVICEDIR}/cep_processing.conf

## OVERRIDE NCORES DEFINED IN CONF FILE
NCORES=36

########################################################################################################
# DEFINE CATEGORICAL RASTER (NAME OF GRASS LAYER) AND MAPSET TO BE ANALYZED WITH R.STATS
IN_RASTER="ecoreg"
IN_RASTER_MAPSET="ECO26"
########################################################################################################

## Derived variables
LOCATION_LL_PATH=${DATABASE}/${LOCATION_LL}
PERMANENT_LL_MAPSET=${DATABASE}/${LOCATION_LL}"/PERMANENT"
OUTCSV_ROOT="cep_"${IN_RASTER}
FINALCSV="r_stats_"${OUTCSV_ROOT}"_"${wdpadate}

## PART I: COMPUTATION OF STATISTICS

echo "Input raster root: "${IN_RASTER}
echo "now running r.stats in parallel on 648 CEP tiles and "${IN_RASTER}" using ${NCORES} threads"

for ttt in $(grass ${DATABASE}/${LOCATION_LL}/"ECO26" --exec  g.list raster mapset=ECO26)
do	
	eid=${ttt#ecoreg_}
	TMP_MAPSET=rst_${eid}
	TMP_MAPSET_PATH=${LOCATION_LL_PATH}/${TMP_MAPSET}
	OUTCSV=${OUTCSV_ROOT}_${eid}.csv
	grass ${PERMANENT_LL_MAPSET} --exec g.mapset --o --q -c ${TMP_MAPSET}
	echo "./slave_cep_catraster_stats.sh ${eid} ${TMP_MAPSET_PATH} ${RESULTSPATH_TMP} ${IN_RASTER}_${eid}@${IN_RASTER_MAPSET} ${OUTCSV} ${CEP_MAPSET}"
done | parallel -j ${NCORES}

wait

## PART II: AGGREGATE CSV TILES
echo " "
echo "r.stats completed, now aggregating results..."
echo " "

rm -f ${RESULTSPATH}/${FINALCSV}.csv
cat ${RESULTSPATH_TMP}/${OUTCSV_ROOT}*.csv >> ${RESULTSPATH}/${FINALCSV}.csv
wait

## PART IV : CREATE PG TABLE AND IMPORT FINAL CSV IN POSTGIS
echo " "
date
echo "Computation of statistics done. Now importing csv table in Postgis..."
echo " "

psql ${dbpar2} -t -v vNAME=${FINALCSV} -v vSCHEMA=${RESULTSCH} -f ./sql/create_table_rstats_qid.sql
psql ${dbpar2} -t -c "\copy ${RESULTSCH}.${FINALCSV} FROM '${RESULTSPATH}/${FINALCSV}.csv' delimiter '|' csv"
psql ${dbpar2} -t -c "DELETE FROM ${RESULTSCH}.${FINALCSV} WHERE cid=0"

## PART V : CLEAN UP (delete mapsets and intermediate results)
rm -rf ${LOCATION_LL_PATH}/rst_*
echo dyn/*.sh |xargs rm -f

for ttt in $(grass ${DATABASE}/${LOCATION_LL}/"ECO26" --exec  g.list raster mapset=ECO26)
do	
	eid=${ttt#ecoreg_}
	rm -f  ${RESULTSPATH_TMP}/${OUTCSV_ROOT}_${eid}.csv
done

enddate=`date +%s`
runtime=$(((enddate-startdate) / 60))

echo "---------------------------------------------------------------------------------------"
echo "Script $(basename "$0") ended at $(date)"
echo "---------------------------------------------------------------------------------------"
echo "Stats on CEP and ${IN_RASTER} computed in "${runtime}" minutes using "${NCORES}" cores "
echo "---------------------------------------------------------------------------------------"
exit
