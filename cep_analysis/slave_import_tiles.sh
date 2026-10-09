#!/bin/bash
##IMPORT RASTER TILES AS INDIVIDUAL RASTER LAYERS

til=$1
MAPSET_PATH=$2
tiles_path=$3
prefix=$4

echo "#!/bin/bash
	## IMPORT RASTER TILE AS EXTERNAL LINK
	r.external --o --q input=${tiles_path}/${til}.tiff output=${prefix}${til}
	exit
	" > ./dyn/import_${prefix}${til}.sh
    chmod u+x ./dyn/import_${prefix}${til}.sh
    grass ${MAPSET_PATH} --exec ./dyn/import_${prefix}${til}.sh
	echo "Tile ${til} imported"
exit
