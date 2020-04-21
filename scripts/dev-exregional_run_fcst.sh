#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHDIR/source_util_funcs.sh
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u +x; } > /dev/null 2>&1
set -xu #cltthink
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located 
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
scrfunc_fn=$( basename "${scrfunc_fp}" )
scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Print message indicating entry into script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Entering script:  \"${scrfunc_fn}\"
In directory:     \"${scrfunc_dir}\"

This is the ex-script for the task that runs a forecast with FV3 for the
specified cycle.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Specify the set of valid argument names for this script/function.  
# Then process the arguments provided to this script/function (which 
# should consist of a set of name-value pairs of the form arg1="value1",
# etc).
#
#-----------------------------------------------------------------------
#
valid_args=( "CYCLE_DIR" )
process_args valid_args "$@"
#
#-----------------------------------------------------------------------
#
# For debugging purposes, print out values of arguments passed to this
# script.  Note that these will be printed out only if VERBOSE is set to
# TRUE.
#
#-----------------------------------------------------------------------
#
print_input_args valid_args
#
#-----------------------------------------------------------------------
#
# Load modules.
#
#-----------------------------------------------------------------------
#
case $MACHINE in
#
"WCOSS_C" | "WCOSS")
#

  if [ "${USE_CCPP}" = "TRUE" ]; then
  
# Needed to change to the experiment directory because the module files
# for the CCPP-enabled version of FV3 have been copied to there.

    cd_vrfy ${DATA}
  
    set +x
    source ./module-setup.sh
    module use $( pwd -P )
    module load modules.fv3
    module list
    set -x
  
  else
  
    . /apps/lmod/lmod/init/sh
    module purge
    module use /scratch4/NCEPDEV/nems/noscrub/emc.nemspara/soft/modulefiles
    module load intel/16.1.150 impi/5.1.1.109 netcdf/4.3.0 
    module list
  
  fi

  ulimit -s unlimited
  ulimit -a
  APRUN="mpirun -l -np ${PE_MEMBER01}"
  ;;
#
"THEIA")
#

  if [ "${USE_CCPP}" = "TRUE" ]; then
  
# Need to change to the experiment directory to correctly load necessary 
# modules for CCPP-version of FV3SAR in lines below
    cd_vrfy ${EXPTDIR}
  
    set +x
    source ./module-setup.sh
    module use $( pwd -P )
    module load modules.fv3
    module load contrib wrap-mpi
    module list
    set -x
  
  else
  
    . /apps/lmod/lmod/init/sh
    module purge
    module use /scratch4/NCEPDEV/nems/noscrub/emc.nemspara/soft/modulefiles
    module load intel/16.1.150 impi/5.1.1.109 netcdf/4.3.0 
    module load contrib wrap-mpi 
    module list
  
  fi

  ulimit -s unlimited
  ulimit -a
  np=${SLURM_NTASKS}
  APRUN="mpirun -np ${np}"
  ;;
#
"HERA")
  ulimit -s unlimited
  ulimit -a
  APRUN="srun --label "
  LD_LIBRARY_PATH="${UFS_WTHR_MDL_DIR}/FV3/ccpp/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  ;;
#
"JET")
#
  . /apps/lmod/lmod/init/sh
  module purge
  module load intel/15.0.3.187
  module load impi/5.1.1.109
  module load szip
  module load hdf5
  module load netcdf4/4.2.1.1
  module load contrib wrap-mpi
  module list

#  . $USHDIR/set_stack_limit_jet.sh
  ulimit -s unlimited
  ulimit -a
  np=${SLURM_NTASKS}
  APRUN="mpirun -np ${np}"
  ;;
#
"ODIN")
#
  module list

  ulimit -s unlimited
  ulimit -a
  APRUN="srun -n ${PE_MEMBER01}"
  ;;
#
esac
#
#-----------------------------------------------------------------------
#
# Create links in the INPUT subdirectory of the current cycle's run di-
# rectory to the grid and (filtered) orography files.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Creating links in the INPUT subdirectory of the current cycle's run di-
rectory to the grid and (filtered) orography files ..."


# Create links to fix files in the FIXsar directory.


cd_vrfy ${DATA}/INPUT

relative_or_null=""
if [ "${RUN_TASK_MAKE_GRID}" = "TRUE" ]; then
  relative_or_null="--relative"
fi

# Symlink to mosaic file with a completely different name.
target="${FIXsar}/${CRES}_mosaic.nc"
symlink="grid_spec.nc"
if [ -f "${target}" ]; then
  ln_vrfy -sf ${relative_or_null} $target $symlink
else
  print_err_msg_exit "\
Cannot create symlink because target does not exist:
  target = \"$target}\""
fi

# Symlink to halo-3 grid file with "halo4" stripped from name.
target="${FIXsar}/${CRES}_grid.tile${TILE_RGNL}.halo${NH3}.nc"
if [ "${RUN_TASK_MAKE_SFC_CLIMO}" = "TRUE" ] && \
   [ "${GRID_GEN_METHOD}" = "GFDLgrid" ] && \
   [ "${GFDLgrid_USE_GFDLgrid_RES_IN_FILENAMES}" = "FALSE" ]; then
  symlink="C${GFDLgrid_RES}_grid.tile${TILE_RGNL}.nc"
else
  symlink="${CRES}_grid.tile${TILE_RGNL}.nc"
fi
if [ -f "${target}" ]; then
  ln_vrfy -sf ${relative_or_null} $target $symlink
else
  print_err_msg_exit "\
Cannot create symlink because target does not exist:
  target = \"$target}\""
fi

# Symlink to halo-4 grid file with "${CRES}_" stripped from name.
#
# If this link is not created, then the code hangs with an error message
# like this:
#
#   check netcdf status=           2
#  NetCDF error No such file or directory
# Stopped
#
# Note that even though the message says "Stopped", the task still con-
# sumes core-hours.
#
target="${FIXsar}/${CRES}_grid.tile${TILE_RGNL}.halo${NH4}.nc"
symlink="grid.tile${TILE_RGNL}.halo${NH4}.nc"
if [ -f "${target}" ]; then
  ln_vrfy -sf ${relative_or_null} $target $symlink
else
  print_err_msg_exit "\
Cannot create symlink because target does not exist:
  target = \"$target}\""
fi



relative_or_null=""
if [ "${RUN_TASK_MAKE_OROG}" = "TRUE" ]; then
  relative_or_null="--relative"
fi

# Symlink to halo-0 orography file with "${CRES}_" and "halo0" stripped from name.
target="${FIXsar}/${CRES}_oro_data.tile${TILE_RGNL}.halo${NH0}.nc"
symlink="oro_data.nc"
if [ -f "${target}" ]; then
  ln_vrfy -sf ${relative_or_null} $target $symlink
else
  print_err_msg_exit "\
Cannot create symlink because target does not exist:
  target = \"$target}\""
fi

#
# Symlink to halo-4 orography file with "${CRES}_" stripped from name.
#
# If this link is not created, then the code hangs with an error message
# like this:
#
#   check netcdf status=           2
#  NetCDF error No such file or directory
# Stopped
#
# Note that even though the message says "Stopped", the task still con-
# sumes core-hours.
#
target="${FIXsar}/${CRES}_oro_data.tile${TILE_RGNL}.halo${NH4}.nc"
symlink="oro_data.tile${TILE_RGNL}.halo${NH4}.nc"
if [ -f "${target}" ]; then
  ln_vrfy -sf ${relative_or_null} $target $symlink
else
  print_err_msg_exit "\
Cannot create symlink because target does not exist:
  target = \"$target}\""
fi


#
#-----------------------------------------------------------------------
#
# The FV3 model looks for the following files in the INPUT subdirectory
# of the run directory:
#
#   gfs_data.nc
#   sfc_data.nc
#   gfs_bndy*.nc
#   gfs_ctrl.nc
#
# Some of these files (gfs_ctrl.nc, gfs_bndy*.nc) already exist, but 
# others do not.  Thus, create links with these names to the appropriate
# files (in this case the initial condition and surface files only).
#
#-----------------------------------------------------------------------
#

if [ $tmmark = tm12 ] ; then
 export FCST_LEN_HRS=6
 export LBC_UPDATE_INTVL_HRS=3
elif [ $tmmark = tm00 ] ; then
 export FCST_LEN_HRS=48
 export LBC_UPDATE_INTVL_HRS=3
else
 export FCST_LEN_HRS=1
 export LBC_UPDATE_INTVL_HRS=1
fi

if [ $tmmark = tm12 ] ; then
FcstInDir=${FcstInDir:-${COMOUT}/gfsanl.${tmmark}}
else
FcstInDir=${FcstInDir:-${COMOUT}/anl.${tmmark}}
fi

if [ $tmmark = tm00 ] ; then
   if [ ${l_use_other_ctrlb_opt:-.false.} = .true. ] ; then
      OtherDirLbc=${COMOUT_CTRLBC}/anl.${tmmark}
      cp $OtherDirLbc/*bndy*tile7*.nc INPUT 
   fi
fi 
cd_vrfy ${DATA}
cp_vrfy  $FcstInDir/*.nc INPUT

numbndy=`ls -l INPUT/gfs_bndy.tile7*.nc | wc -l`
let "numbndy_check=${FCST_LEN_HRS}/${LBC_UPDATE_INTVL_HRS}+1"

if [ $tmmark = tm00 ] ; then
  if [ $numbndy -lt $numbndy_check ] ; then
    export err=13
    echo "Don't have all BC files at tm00, abort run"
    echo  "Don't have all BC files at tm00, abort run"
    exit
  fi
  elif  [ $tmmark = tm12 ] ; then 
   if [ $numbndy -ne 3 ] ; then
    export err=4
    echo "Don't have both BC files at ${tmmark}, abort run"
    echo "Don't have all BC files at ${tmmark}, abort run"
    exit
   fi
else
  if [ $numbndy -lt 2 ] ; then
    export err=2
    echo "Don't have both BC files at ${tmmark}, abort run"
    echo  "Don't have all BC files at ${tmmark}, abort run"
    exit
  fi
fi



print_info_msg "$VERBOSE" "
Creating links with names that FV3 looks for in the INPUT subdirectory
of the current cycle's run directory (DATA)..."
cd_vrfy  ${DATA}/INPUT
#ln_vrfy -sf gfs_data.tile${TILE_RGNL}.halo${NH0}.nc gfs_data.nc
#ln_vrfy -sf sfc_data.tile${TILE_RGNL}.halo${NH0}.nc sfc_data.nc

relative_or_null=""
if [ ${tmmark:-tm12}  = tm12 ] ; then
     target="gfs_data.tile${TILE_RGNL}.halo${NH0}.nc"
     symlink="gfs_data.nc"
     if [ -f "${target}" ]; then
       ln_vrfy -sf ${relative_or_null} $target $symlink
     else
       print_err_msg_exit "\
     Cannot create symlink because target does not exist:
       target = \"$target}\""
     fi


     target="sfc_data.tile${TILE_RGNL}.halo${NH0}.nc"
     symlink="sfc_data.nc"
     if [ -f "${target}" ]; then
       ln_vrfy -sf ${relative_or_null} $target $symlink
     else
       print_err_msg_exit "\
     Cannot create symlink because target does not exist:
       target = \"$target}\""
     fi
fi  # tm12 
#
#-----------------------------------------------------------------------
#
# Create links in the current cycle's run directory to "fix" files in 
# the main experiment directory.
#
#-----------------------------------------------------------------------
#
cd_vrfy ${DATA}

print_info_msg "$VERBOSE" "
Creating links in the current cycle's run directory to static (fix) 
files in the FIXam directory..."
#
# If running in "nco" mode, FIXam is simply a symlink under the workflow
# directory that points to the system directory containing the fix 
# files.  The files in this system directory are named as listed in the
# FIXgsm_FILENAMES array.  Thus, that is the array to use to form the
# names of the targets of the symlinks, but the names of the symlinks themselves
# must be as specified in the FIXam_FILENAMES array (because that 
# array contains the file names that FV3 looks for).
#
if [ "${RUN_ENVIR}" = "nco" ]; then

  for (( i=0; i<${NUM_FIXam_FILES}; i++ )); do
# Note: Can link directly to files in FIXgsm without needing a local
# FIXam directory, i.e. use
#    ln_vrfy -sf $FIXgsm/${FIXgsm_FILENAMES[$i]} \
#                ${DATA}/${FIXam_FILENAMES[$i]}
    ln_vrfy -sf $FIXam/${FIXgsm_FILENAMES[$i]} \
                ${DATA}/${FIXam_FILENAMES[$i]}
  done

#cltthink added by tl
#----------------------------------------------
# Copy all the necessary fix files
#----------------------------------------------
cd $DATA
cp $FIXam/global_solarconstant_noaa_an.txt            solarconstant_noaa_an.txt
cp $FIXam/ozprdlos_2015_new_sbuvO3_tclm15_nuchem.f77  global_o3prdlos.f77
cp $FIXam/global_h2o_pltc.f77                         global_h2oprdlos.f77
cp $FIXam/global_sfc_emissivity_idx.txt               sfc_emissivity_idx.txt
cp $FIXam/global_co2historicaldata_glob.txt           co2historicaldata_glob.txt
cp $FIXam/co2monthlycyc.txt                           co2monthlycyc.txt
cp $FIXam/global_climaeropac_global.txt               aerosol.dat

cp $FIXam/global_glacier.2x2.grb .
cp $FIXam/global_maxice.2x2.grb .
cp $FIXam/RTGSST.1982.2012.monthly.clim.grb .
cp $FIXam/global_snoclim.1.875.grb .
cp $FIXam/CFSR.SEAICE.1982.2012.monthly.clim.grb .
cp $FIXam/global_soilmgldas.t1534.3072.1536.grb .
cp $FIXam/seaice_newland.grb .
cp $FIXam/global_shdmin.0.144x0.144.grb .
cp $FIXam/global_shdmax.0.144x0.144.grb .

#clt copy from Ratko
#RV ---- HARDCODED ---- please help here!
ln_vrfy -sf $FIXsar/C768.facsf.tile1.nc \
            ${DATA}/C768.facsf.tile1.nc
ln_vrfy -sf $FIXsar/C768.maximum_snow_albedo.tile1.nc \
            ${DATA}/C768.maximum_snow_albedo.tile1.nc
ln_vrfy -sf $FIXsar/C768.slope_type.tile1.nc \
            ${DATA}/C768.slope_type.tile1.nc
ln_vrfy -sf $FIXsar/C768.snowfree_albedo.tile1.nc \
            ${DATA}/C768.snowfree_albedo.tile1.nc
ln_vrfy -sf $FIXsar/C768.soil_type.tile1.nc \
            ${DATA}/C768.soil_type.tile1.nc
ln_vrfy -sf $FIXsar/C768.substrate_temperature.tile1.nc \
            ${DATA}/C768.substrate_temperature.tile1.nc
ln_vrfy -sf $FIXsar/C768.vegetation_greenness.tile1.nc \
            ${DATA}/C768.vegetation_greenness.tile1.nc
ln_vrfy -sf $FIXsar/C768.vegetation_type.tile1.nc \
            ${DATA}/C768.vegetation_type.tile1.nc

rm_vrfy     ${DATA}/global_soilmgldas.t126.384.190.grb
ln_vrfy -sf $FIXam/global_soilmgldas.t1534.3072.1536.grb \
            ${DATA}/global_soilmgldas.t1534.3072.1536.grb


#clt for file in `ls $FIXco2/global_co2historicaldata* ` ; do
#  cp $file $(echo $(basename $file) |sed -e "s/global_//g")
#clt done

#----------------------------------------------
# Copy tile data and orography for regional
#----------------------------------------------
#this block to be think
ntiles=1
tile=7
cp $FIXsar/${CRES}_grid.tile${tile}.halo3.nc INPUT/.
cp $FIXsar/${CRES}_grid.tile${tile}.halo4.nc INPUT/.
cp $FIXsar/${CRES}_oro_data.tile${tile}.halo0.nc INPUT/.
cp $FIXsar/${CRES}_oro_data.tile${tile}.halo4.nc INPUT/.
cp $FIXsar/${CRES}_mosaic.nc INPUT/.

cd INPUT
ln -sf ${CRES}_mosaic.nc grid_spec.nc
ln -sf ${CRES}_grid.tile7.halo3.nc ${CRES}_grid.tile1.nc
ln -sf ${CRES}_grid.tile7.halo4.nc grid.tile1.halo4.nc
ln -sf ${CRES}_oro_data.tile7.halo0.nc oro_data.nc
ln -sf ${CRES}_oro_data.tile7.halo4.nc oro_data.tile7.halo4.nc
# Initial Conditions are needed for SAR but not SAR-DA
if [ ${tmmark} = tm12 ] ; then
  ln -sf sfc_data.tile7.halo${NH0}.nc sfc_data.nc
  ln -sf gfs_data.tile7.halo${NH0}.nc gfs_data.nc
fi



#clt            ${CYCLE_DIR}/global_soilmgldas.t1534.3072.1536.grb
#ls ./atmos_static.nc

#
# If not running in "nco" mode, FIXam is an actual directory (not a sym-
# link) in the experiment directory that contains the same files as the
# system fix directory except that the files have been renamed to the
# file names that FV3 looks for.  Thus, when creating links to the files
# in this directory, both the target and symlink names should be the 
# ones specified in the FIXam_FILENAMES array (because that array 
# contains the file names that FV3 looks for).
#
else

  for (( i=0; i<${NUM_FIXam_FILES}; i++ )); do
    ln_vrfy -sf --relative $FIXam/${FIXam_FILENAMES[$i]} ${DATA}
  done

fi
#
#-----------------------------------------------------------------------
#
# If running this cycle more than once (e.g. using rocotoboot), remove
# any time stamp file that may exist from the previous attempt.
#
#-----------------------------------------------------------------------
#
cd_vrfy ${DATA}
rm_vrfy -f time_stamp.out
#
#-----------------------------------------------------------------------
#
# Create links in the current cycle's run directory to cycle-independent
# model input files in the main experiment directory.
#
#-----------------------------------------------------------------------
#
if [ ${tmmark:-tm12}  = tm12 ] ; then
   export FV3_NML_FP=$EXPTDIR/input.nml_sar_firstguess
elif [ ${tmmark:-tm12}  = tm00 ] ; then
   export FV3_NML_FP=$EXPTDIR/input.nml_sar_da
else
   export FV3_NML_FP=$EXPTDIR/input.nml_sar_da_hourly
fi
print_info_msg "$VERBOSE" "
Creating links in the current cycle's run directory to cycle-independent
model input files in the main experiment directory..."


ln_vrfy -sf -t ${DATA} ${DATA_TABLE_FP}
ln_vrfy -sf -t ${DATA} ${FIELD_TABLE_FP}
#cltorg ln_vrfy -sf -t ${DATA} ${FV3_NML_FP}
ln_vrfy -sf ${FV3_NML_FP} ${DATA}/input.nml
ln_vrfy -sf -t ${DATA} ${NEMS_CONFIG_FP}

if [ "${USE_CCPP}" = "TRUE" ]; then

  ln_vrfy -sf -t ${DATA} ${CCPP_PHYS_SUITE_FP}

  if [ "${CCPP_PHYS_SUITE}" = "FV3_GSD_v0" ] || \
     [ "${CCPP_PHYS_SUITE}" = "FV3_GSD_SAR" ]; then
    ln_vrfy -sf -t ${DATA} $EXPTDIR/CCN_ACTIVATE.BIN
  fi

fi
#
#-----------------------------------------------------------------------
#
# Copy templates of cycle-dependent model input files from the templates
# directory to the current cycle's run directory.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Copying cycle-dependent model input files from the templates directory 
to the current cycle's run directory..." 

print_info_msg "$VERBOSE" "
  Copying the template diagnostics table file to the current cycle's run
  directory..."
diag_table_fp="${DATA}/${DIAG_TABLE_FN}"
cp_vrfy "${DIAG_TABLE_TMPL_FP}" "${diag_table_fp}"

print_info_msg "$VERBOSE" "
  Copying the template model configuration file to the current cycle's
  run directory..."
model_config_fp="${DATA}/${MODEL_CONFIG_FN}"
cp_vrfy "${MODEL_CONFIG_TMPL_FP}" "${model_config_fp}"
#
#-----------------------------------------------------------------------
#
# Extract from CDATE the starting year, month, day, and hour of the
# forecast.  These are needed below for various operations.
#
#-----------------------------------------------------------------------
#
YYYY=${CYCLEinit:0:4}
MM=${CYCLEinit:4:2}
DD=${CYCLEinit:6:2}
HH=${CYCLEinit:8:2}
YYYYMMDD=${CYCLEinit:0:8}
#
#-----------------------------------------------------------------------
#
# Set parameters in the diagnostics table file.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Setting parameters in file:
  diag_table_fp = \"${diag_table_fp}\""

set_file_param "${diag_table_fp}" "CRES" "$CRES"
set_file_param "${diag_table_fp}" "YYYY" "$YYYY"
set_file_param "${diag_table_fp}" "MM" "$MM"
set_file_param "${diag_table_fp}" "DD" "$DD"
set_file_param "${diag_table_fp}" "HH" "$HH"
set_file_param "${diag_table_fp}" "YYYYMMDD" "$YYYYMMDD"
#
#-----------------------------------------------------------------------
#
# Set parameters in the model configuration file.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Setting parameters in file:
  model_config_fp = \"${model_config_fp}\""

dot_quilting_dot="."${QUILTING,,}"."
dot_print_esmf_dot="."${PRINT_ESMF,,}"."

set_file_param "${model_config_fp}" "PE_MEMBER01" "${PE_MEMBER01}"
set_file_param "${model_config_fp}" "dt_atmos" "${DT_ATMOS}"
set_file_param "${model_config_fp}" "start_year" "$YYYY"
set_file_param "${model_config_fp}" "start_month" "$MM"
set_file_param "${model_config_fp}" "start_day" "$DD"
set_file_param "${model_config_fp}" "start_hour" "$HH"
set_file_param "${model_config_fp}" "nhours_fcst" "${FCST_LEN_HRS}"
set_file_param "${model_config_fp}" "ncores_per_node" "${NCORES_PER_NODE}"
set_file_param "${model_config_fp}" "quilting" "${dot_quilting_dot}"
set_file_param "${model_config_fp}" "print_esmf" "${dot_print_esmf_dot}"
#
#-----------------------------------------------------------------------
#
# If the write component is to be used, then a set of parameters, in-
# cluding those that define the write component's output grid, need to
# be specified in the model configuration file (model_config_fp).  This
# is done by appending a template file (in which some write-component
# parameters are set to actual values while others are set to placehol-
# ders) to model_config_fp and then replacing the placeholder values in
# the (new) model_config_fp file with actual values.  The full path of
# this template file is specified in the variable WRTCMP_PA RAMS_TEMP-
# LATE_FP.
#
#-----------------------------------------------------------------------
#
if [ "$QUILTING" = "TRUE" ]; then

  cat ${WRTCMP_PARAMS_TMPL_FP} >> ${model_config_fp}

  set_file_param "${model_config_fp}" "write_groups" "$WRTCMP_write_groups"
  set_file_param "${model_config_fp}" "write_tasks_per_group" "$WRTCMP_write_tasks_per_group"

  set_file_param "${model_config_fp}" "output_grid" "\'$WRTCMP_output_grid\'"
  set_file_param "${model_config_fp}" "cen_lon" "$WRTCMP_cen_lon"
  set_file_param "${model_config_fp}" "cen_lat" "$WRTCMP_cen_lat"
  set_file_param "${model_config_fp}" "lon1" "$WRTCMP_lon_lwr_left"
  set_file_param "${model_config_fp}" "lat1" "$WRTCMP_lat_lwr_left"

  if [ "${WRTCMP_output_grid}" = "rotated_latlon" ]; then
    set_file_param "${model_config_fp}" "lon2" "$WRTCMP_lon_upr_rght"
    set_file_param "${model_config_fp}" "lat2" "$WRTCMP_lat_upr_rght"
    set_file_param "${model_config_fp}" "dlon" "$WRTCMP_dlon"
    set_file_param "${model_config_fp}" "dlat" "$WRTCMP_dlat"
  elif [ "${WRTCMP_output_grid}" = "lambert_conformal" ]; then
    set_file_param "${model_config_fp}" "stdlat1" "$WRTCMP_stdlat1"
    set_file_param "${model_config_fp}" "stdlat2" "$WRTCMP_stdlat2"
    set_file_param "${model_config_fp}" "nx" "$WRTCMP_nx"
    set_file_param "${model_config_fp}" "ny" "$WRTCMP_ny"
    set_file_param "${model_config_fp}" "dx" "$WRTCMP_dx"
    set_file_param "${model_config_fp}" "dy" "$WRTCMP_dy"
  elif [ "${WRTCMP_output_grid}" = "regional_latlon" ]; then
    set_file_param "${model_config_fp}" "lon2" "$WRTCMP_lon_upr_rght"
    set_file_param "${model_config_fp}" "lat2" "$WRTCMP_lat_upr_rght"
    set_file_param "${model_config_fp}" "dlon" "$WRTCMP_dlon"
    set_file_param "${model_config_fp}" "dlat" "$WRTCMP_dlat"
  fi

fi
#
#-----------------------------------------------------------------------
#
# Copy the FV3SAR executable to the run directory.
#
#-----------------------------------------------------------------------
#
if [ "${USE_CCPP}" = "TRUE" ]; then
  FV3SAR_EXEC="${UFS_WTHR_MDL_DIR}/tests/fv3.exe"
else
  FV3SAR_EXEC="${UFS_WTHR_MDL_DIR}/tests/fv3_32bit.exe"
fi
#clthinkdeb
  FV3SAR_EXEC="/scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/unified-regional_workflow/expt_dirs/test4emc/Ratko-fv3-gfs.x"

if [ -f $FV3SAR_EXEC ]; then
  print_info_msg "$VERBOSE" "
Copying the FV3SAR executable to the run directory..."
#cltthink temporal work-aroun
if [ $tmmark = tm12 ] ; then
  cp_vrfy ${FV3SAR_EXEC} ${DATA}/fv3_gfs.x
else
  cp  /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-eric/regional_workflow/exec//regional_forecast.x ${DATA}/fv3_gfs.x
fi
else
  print_err_msg_exit "\
The FV3SAR executable specified in FV3SAR_EXEC does not exist:
  FV3SAR_EXEC = \"$FV3SAR_EXEC\"
Build FV3SAR and rerun."
fi
#
#-----------------------------------------------------------------------
#
# Set and export variables.
#
#-----------------------------------------------------------------------
#
export KMP_AFFINITY=scatter
export OMP_NUM_THREADS=1 #Needs to be 1 for dynamic build of CCPP with GFDL fast physics, was 2 before.
export OMP_STACKSIZE=1024m
#
#-----------------------------------------------------------------------
#
# Run the FV3SAR model.  Note that we have to launch the forecast from
# the current cycle's run directory because the FV3 executable will look
# for input files in the current directory.  Since those files have been 
# staged in the run directory, the current directory must be the run di-
# rectory (which it already is).
#
#-----------------------------------------------------------------------
#
#ctl $APRUN ./fv3_gfs.x || print_err_msg_exit "\
srun --label --ntasks=1440  --ntasks-per-node=20  --cpus-per-task=2  ./fv3_gfs.x || print_err_msg_exit "\
Call to executable to run FV3SAR forecast returned with nonzero exit 
code."
report-mem

#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
FV3 forecast completed successfully!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#clt ------------------------------------------------
FcstOutDir=${FcstOutDir:-$GUESSdir}
if [ $tmmark != tm00 ] ; then
  cp grid_spec.nc $FcstOutDir/.
  cd RESTART
#cltorg   mv ${PDYfcst}.${CYCfcst}0000.coupler.res $FcstOutDir/${PDYfcst}.${CYCfcst}0000.${memstr+"_${memstr}_"}coupler.res
#cltorg   mv ${PDYfcst}.${CYCfcst}0000.fv_core.res.nc $FcstOutDir/${PDYfcst}.${CYCfcst}0000.${memstr+"_${memstr}_"}fv_core.res.nc
#cltorg   mv ${PDYfcst}.${CYCfcst}0000.fv_core.res.tile1.nc $FcstOutDir/${PDYfcst}.${CYCfcst}0000.${memstr+"_${memstr}_"}fv_core.res.tile1.nc
#cltorg   mv ${PDYfcst}.${CYCfcst}0000.fv_tracer.res.tile1.nc $FcstOutDir/${PDYfcst}.${CYCfcst}0000.${memstr+"_${memstr}_"}fv_tracer.res.tile1.nc
#cltorg  mv ${PDYfcst}.${CYCfcst}0000.sfc_data.nc $FcstOutDir/${PDYfcst}.${CYCfcst}0000.${memstr+"_${memstr}_"}sfc_data.nc


  mv coupler.res $FcstOutDir/${PDYfcst}.${CYCfcst}0000.coupler.res
  mv fv_core.res.nc $FcstOutDir/${PDYfcst}.${CYCfcst}0000.${memstr+"_${memstr}_"}fv_core.res.nc
  mv fv_core.res.tile1.nc $FcstOutDir/${PDYfcst}.${CYCfcst}0000.${memstr+"_${memstr}_"}fv_core.res.tile1.nc
  mv fv_tracer.res.tile1.nc $FcstOutDir/${PDYfcst}.${CYCfcst}0000.${memstr+"_${memstr}_"}fv_tracer.res.tile1.nc
  mv sfc_data.nc $FcstOutDir/${PDYfcst}.${CYCfcst}0000.${memstr+"_${memstr}_"}sfc_data.nc


# These are not used in GSI but are needed to warmstart FV3
# so they go directly into ANLdir
#cltorg  mv ${PDYfcst}.${CYCfcst}0000.phy_data.nc $FcstOutDir/phy_data.nc
  mv phy_data.nc $FcstOutDir/phy_data.nc
fi
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

