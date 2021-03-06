#!/bin/sh
set -xeu

build_dir=`pwd`

CP='cp -rp'

# Check final exec folder exists
if [ ! -d "../exec" ]; then
  echo "Creating ../exec folder"
  mkdir ../exec
fi

#------------------------------------
# INCLUDE PARTIAL BUILD 
#------------------------------------

. ./partial_build.sh

#------------------------------------
# install forecast
#------------------------------------
$Build_forecast && {
 ${CP} ufs-weather-model/NEMS/exe/NEMS.x                   ../exec/regional_forecast.x
}
$Build_forecast_ccpp && {
 ${CP} ufs-weather-model/NEMS/exe/NEMS.x                   ../exec/regional_forecast.x
}

#------------------------------------
# install post
#------------------------------------
$Build_post && {
 ${CP} EMC_post/exec/ncep_post                             ../exec/ncep_post
}

#------------------------------------
# install chgres
#------------------------------------
$Build_chgres && {
 ${CP} regional_utils.fd/exec/global_chgres                ../exec/regional_chgres.x
}

#------------------------------------
# install chgres_cube
#------------------------------------
$Build_chgres_cube && {
 ${CP} UFS_UTILS_develop/exec/chgres_cube.exe              ../exec/chgres_cube.exe
}

#------------------------------------
# install orog
#------------------------------------
$Build_orog && {
 ${CP} UFS_UTILS_develop/exec/orog.x                       ../exec/orog.x
}

#------------------------------------
# install sfc_climo_gen
#------------------------------------
$Build_sfc_climo_gen && {
 ${CP} UFS_UTILS_develop/exec/sfc_climo_gen                ../exec/sfc_climo_gen
}

#------------------------------------
# install regional_grid
#------------------------------------
$Build_regional_grid && {
 ${CP} regional_grid.fd/exec/regional_grid                 ../exec/regional_grid.x
}

#------------------------------------
# install mosaic_file
#------------------------------------
$Build_mosaic_file && {
 ${CP} mosaic_file.fd/exec/mosaic_file                     ../exec/make_solo_mosaic.x
}

#------------------------------------
# install global_equiv_resol
#------------------------------------
$Build_global_equiv_resol && {
 ${CP} global_equiv_resol.fd/exec/global_equiv_resol       ../exec/global_equiv_resol.x
}

#------------------------------------
# install fre-nctools
#------------------------------------
$Build_nctools && {
 ${CP} UFS_UTILS_develop/exec/make_hgrid                   ../exec/make_hgrid
 ${CP} UFS_UTILS_develop/exec/make_hgrid_parallel          ../exec/make_hgrid_parallel
 ${CP} UFS_UTILS_develop/exec/make_solo_mosaic             ../exec/make_solo_mosaic
 ${CP} UFS_UTILS_develop/exec/fregrid                      ../exec/fregrid
 ${CP} UFS_UTILS_develop/exec/fregrid_parallel             ../exec/fregrid_parallel
 ${CP} UFS_UTILS_develop/exec/filter_topo                  ../exec/filter_topo
 ${CP} UFS_UTILS_develop/exec/shave.x                      ../exec/shave.x
}

#------------------------------------
# install gsi
#------------------------------------
$Build_gsi && {
 ${CP} regional_gsi.fd/exec/global_gsi.x                   ../exec/regional_gsi.x
 ${CP} regional_gsi.fd/exec/global_enkf.x                  ../exec/regional_enkf.x
 ${CP} regional_gsi.fd/exec/adderrspec.x                   ../exec/regional_adderrspec.x
 ${CP} regional_gsi.fd/exec/adjustps.x                     ../exec/regional_adjustps.x
 ${CP} regional_gsi.fd/exec/calc_increment_ens.x           ../exec/regional_calc_increment_ens.x
 ${CP} regional_gsi.fd/exec/calc_increment_serial.x        ../exec/regional_calc_increment_serial.x
 ${CP} regional_gsi.fd/exec/getnstensmeanp.x               ../exec/regional_getnstensmeanp.x
 ${CP} regional_gsi.fd/exec/getsfcensmeanp.x               ../exec/regional_getsfcensmeanp.x
 ${CP} regional_gsi.fd/exec/getsfcnstensupdp.x             ../exec/regional_getsfcnstensupdp.x
 ${CP} regional_gsi.fd/exec/getsigensmeanp_smooth.x        ../exec/regional_getsigensmeanp_smooth.x
 ${CP} regional_gsi.fd/exec/getsigensstatp.x               ../exec/regional_getsigensstatp.x
 ${CP} regional_gsi.fd/exec/gribmean.x                     ../exec/regional_gribmean.x
 ${CP} regional_gsi.fd/exec/nc_diag_cat.x                  ../exec/regional_nc_diag_cat.x
 ${CP} regional_gsi.fd/exec/nc_diag_cat_serial.x           ../exec/regional_nc_diag_cat_serial.x
 ${CP} regional_gsi.fd/exec/oznmon_horiz.x                 ../exec/regional_oznmon_horiz.x
 ${CP} regional_gsi.fd/exec/oznmon_time.x                  ../exec/regional_oznmon_time.x
 ${CP} regional_gsi.fd/exec/radmon_angle.x                 ../exec/regional_radmon_angle.x
 ${CP} regional_gsi.fd/exec/radmon_bcoef.x                 ../exec/regional_radmon_bcoef.x
 ${CP} regional_gsi.fd/exec/radmon_bcor.x                  ../exec/regional_radmon_bcor.x
 ${CP} regional_gsi.fd/exec/radmon_time.x                  ../exec/regional_radmon_time.x
 ${CP} regional_gsi.fd/exec/recenternemsiop_hybgain.x      ../exec/regional_recenternemsiop_hybgain.x
 ${CP} regional_gsi.fd/exec/recentersigp.x                 ../exec/regional_recentersigp.x
 ${CP} regional_gsi.fd/exec/test_nc_unlimdims.x            ../exec/regional_test_nc_unlimdims.x
}

echo;echo " .... Install system finished .... "

exit 0
