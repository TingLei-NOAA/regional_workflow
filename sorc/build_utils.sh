#!/bin/sh

set -eux

. ../ush/source_util_funcs.sh

export USE_PREINST_LIBS="true"

#------------------------------------
# END USER DEFINED STUFF
#------------------------------------

build_dir=`pwd`
logs_dir=$build_dir/logs
if [ ! -d $logs_dir  ]; then
  echo "Creating logs folder"
  mkdir $logs_dir
fi

#------------------------------------
# INCLUDE PARTIAL BUILD 
#------------------------------------

. ./partial_build.sh


#------------------------------------
# Get from the manage_externals configuration file the relative directo-
# ries in which the UFS utility codes (not including chgres_cube) and 
# the chgres_cube codes get cloned.  Note that these two sets of codes
# are in the same repository but different branches.  These directories
# will be relative to the workflow home directory, which we denote below
# by HOMErrfs.  Then form the absolute paths to these codes.
#------------------------------------
HOMErrfs=$( readlink -f "${build_dir}/.." )
mng_extrns_cfg_fn="${HOMErrfs}/Externals.cfg"
property_name="local_path"

# First, consider the UFS utility codes, not including chgres (i.e. we
# do not use any versions of chgres or chgres_cube in this set of codes).
external_name="ufs_utils"
UFS_UTILS_DEV=$( \
get_manage_externals_config_property \
"${mng_extrns_cfg_fn}" "${external_name}" "${property_name}" ) || \
print_err_msg_exit "\
Call to function get_manage_config_externals_property failed."
UFS_UTILS_DEV="${HOMErrfs}/${UFS_UTILS_DEV}/sorc"

# Next, consider the chgres_cube code.
#RV external_name="ufs_utils_chgres"
#RV UFS_UTILS_CHGRES_GRIB2=$( \
#RV get_manage_externals_config_property \
#RV "${mng_extrns_cfg_fn}" "${external_name}" "${property_name}" ) || \
#RV print_err_msg_exit "\
#RV Call to function get_manage_externals_config_property failed."
#RV UFS_UTILS_CHGRES_GRIB2="${HOMErrfs}/${UFS_UTILS_CHGRES_GRIB2}/sorc"

#------------------------------------
# build chgres
#------------------------------------
$Build_chgres && {
echo " .... Chgres build not currently supported .... "
#echo " .... Building chgres .... "
#./build_chgres.sh > $logs_dir/build_chgres.log 2>&1
}

#------------------------------------
# build chgres_cube
#------------------------------------
$Build_chgres_cube && {
echo " .... Building chgres_cube .... "
cd $UFS_UTILS_DEV
./build_chgres_cube.sh > $logs_dir/build_chgres_cube.log 2>&1
}

#------------------------------------
# build orog
#------------------------------------
$Build_orog && {
echo " .... Building orog .... "
cd $UFS_UTILS_DEV
./build_orog.sh > $logs_dir/build_orog.log 2>&1
}

#------------------------------------
# build fre-nctools
#------------------------------------
$Build_nctools && {
echo " .... Building fre-nctools .... "
cd $UFS_UTILS_DEV
./build_fre-nctools.sh > $logs_dir/build_fre-nctools.log 2>&1
}

#------------------------------------
# build sfc_climo_gen
#------------------------------------
$Build_sfc_climo_gen && {
echo " .... Building sfc_climo_gen .... "
cd $UFS_UTILS_DEV
./build_sfc_climo_gen.sh > $logs_dir/build_sfc_climo_gen.log 2>&1
}

#------------------------------------
# build regional_grid
#------------------------------------
$Build_regional_grid && {
echo " .... Building regional_grid .... "
cd $build_dir
./build_regional_grid.sh > $logs_dir/build_regional_grid.log 2>&1
}

#------------------------------------
# build global_equiv_resol
#------------------------------------
$Build_global_equiv_resol && {
echo " .... Building global_equiv_resol .... "
cd $build_dir
./build_global_equiv_resol.sh > $logs_dir/build_global_equiv_resol.log 2>&1
}

#------------------------------------
# build mosaic file
#------------------------------------
$Build_mosaic_file && {
echo " .... Building mosaic_file .... "
cd $build_dir
./build_mosaic_file.sh > $logs_dir/build_mosaic_file.log 2>&1
}

cd $build_dir

echo 'Building utils done'
