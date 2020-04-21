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

This is the ex-script for the task that runs the post-processor (UPP) on
the output files corresponding to a specified forecast hour.
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
valid_args=( "cycle_dir" "postprd_dir" "fhr_dir" "fhr" )
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
print_info_msg "$VERBOSE" "
Starting post-processing for fhr = $fhr hr..."

case $MACHINE in


"WCOSS_C" | "WCOSS" )
#  { save_shell_opts; set +x; } > /dev/null 2>&1
  module purge
  . $MODULESHOME/init/ksh
  module load PrgEnv-intel ESMF-intel-haswell/3_1_0rp5 cfp-intel-sandybridge iobuf craype-hugepages2M craype-haswell
#  module load cfp-intel-sandybridge/1.1.0
  module use /gpfs/hps/nco/ops/nwprod/modulefiles
  module load prod_envir
#  module load prod_util
  module load prod_util/1.0.23
  module load grib_util/1.0.3
  module load crtm-intel/2.2.5
  module list
#  { restore_shell_opts; } > /dev/null 2>&1

# Specify computational resources.
  export NODES=8
  export ntasks=96
  export ptile=12
  export threads=1
  export MP_LABELIO=yes
  export OMP_NUM_THREADS=$threads

  APRUN="aprun -j 1 -n${ntasks} -N${ptile} -d${threads} -cc depth"
  ;;


"THEIA")
  { save_shell_opts; set +x; } > /dev/null 2>&1
  module purge
  module load intel
  module load impi 
  module load netcdf
  module load contrib wrap-mpi
  { restore_shell_opts; } > /dev/null 2>&1
  np=${SLURM_NTASKS}
  APRUN="mpirun -np ${np}"
  ;;


"HERA")
  module load wgrib2/2.0.8 #cltthink
#  export NDATE=/scratch3/NCEPDEV/nwprod/lib/prod_util/v1.1.0/exec/ndate
  APRUN="srun"
  ;;


"JET")
  { save_shell_opts; set +x; } > /dev/null 2>&1
  module purge 
  . /apps/lmod/lmod/init/sh 
  module load newdefaults
  module load intel/15.0.3.187
  module load impi/5.1.1.109
  module load szip
  module load hdf5
  module load netcdf4/4.2.1.1
  
  set libdir /mnt/lfs3/projects/hfv3gfs/gwv/ljtjet/lib
  
  export NCEPLIBS=/mnt/lfs3/projects/hfv3gfs/gwv/ljtjet/lib

  module use /mnt/lfs3/projects/hfv3gfs/gwv/ljtjet/lib/modulefiles
  module load bacio-intel-sandybridge
  module load sp-intel-sandybridge
  module load ip-intel-sandybridge
  module load w3nco-intel-sandybridge
  module load w3emc-intel-sandybridge
  module load nemsio-intel-sandybridge
  module load sfcio-intel-sandybridge
  module load sigio-intel-sandybridge
  module load g2-intel-sandybridge
  module load g2tmpl-intel-sandybridge
  module load gfsio-intel-sandybridge
  module load crtm-intel-sandybridge
  
  module use /lfs3/projects/hfv3gfs/emc.nemspara/soft/modulefiles
  module load esmf/7.1.0r_impi_optim
  module load contrib wrap-mpi
  { restore_shell_opts; } > /dev/null 2>&1

  np=${SLURM_NTASKS}
  APRUN="mpirun -np ${np}"
  ;;


"ODIN")
  APRUN="srun -n 1"
  ;;


esac
#
#-----------------------------------------------------------------------
#
# Remove any files from previous runs and stage necessary files in fhr_dir.
#
#-----------------------------------------------------------------------
#
set -xu
rm_vrfy -f fort.*
cp_vrfy $FIXupp/nam_micro_lookup.dat ./eta_micro_lookup.dat
cp_vrfy $FIXupp/postxconfig-NT-fv3sar.txt ./postxconfig-NT.txt
cp_vrfy $FIXupp/params_grib2_tbl_new ./params_grib2_tbl_new
#clt cp_vrfy ${EXECDIR}/ncep_post .
POSTGPEXEC=/scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-wen/EMC_post/sorc/ncep_post.fd/ncep_post
cp_vrfy $POSTGPEXEC  .
#
#-----------------------------------------------------------------------
#
# Get the cycle date and hour (in formats of yyyymmdd and hh, respect-
# ively) from CDATE.
#
#-----------------------------------------------------------------------
#
#cltorg  yyyymmdd=${CDATE:0:8}
#cltorg hh=${CDATE:8:2}
#cltorg cyc=$hh
#cltorg tmmark="tm$hh"

if [ $tmmark = tm00 ] ; then
  export NEWDATE=`${NDATE} +${fhr} $CDATE`
else
  offset=`echo $tmmark | cut -c 3-4`
  export vlddate=`${NDATE} -${offset} $CDATE`
  export NEWDATE=`${NDATE} +${fhr} $vlddate`
fi
export POST_YYYY=`echo $NEWDATE | cut -c1-4`
export POST_MM=`echo $NEWDATE | cut -c5-6`
export POST_DD=`echo $NEWDATE | cut -c7-8`
export POST_HH=`echo $NEWDATE | cut -c9-10`

#
#-----------------------------------------------------------------------
#
# Create a text file (itag) containing arguments to pass to the post-
# processing executable.
#
#-----------------------------------------------------------------------
#
#cltorg dyn_file="${cycle_dir}/dynf0${fhr}.nc"
#cltorg phy_file="${cycle_dir}/phyf0${fhr}.nc"
dyn_file="${INPUT_DATA_DIR}/dynf0${fhr}.nc"
phy_file="${INPUT_DATA_DIR}/phyf0${fhr}.nc"

#POST_TIME=$( ${NDATE} +${fhr} ${CDATE} )
#cltorg POST_TIME=$( date --utc --date "${yyyymmdd} ${hh} UTC + ${fhr} hours" "+%Y%m%d%H" )
#cltorg POST_YYYY=${POST_TIME:0:4}
#cltorg POST_MM=${POST_TIME:4:2}
#cltorg POST_DD=${POST_TIME:6:2}
#cltorg POST_HH=${POST_TIME:8:2}

cat > itag <<EOF
${dyn_file}
netcdf
grib2
${POST_YYYY}-${POST_MM}-${POST_DD}_${POST_HH}:00:00
FV3R
${phy_file}

 &NAMPGB
 KPO=47,PO=1000.,975.,950.,925.,900.,875.,850.,825.,800.,775.,750.,725.,700.,675.,650.,625.,600.,575.,550.,525.,500.,475.,450.,425.,400.,375.,350.,325.,300.,275.,250.,225.,200.,175.,150.,125.,100.,70.,50.,30.,20.,10.,7.,5.,3.,2.,1.,
 /
EOF
#
#-----------------------------------------------------------------------
#
# Copy the UPP executable to fhr_dir and run the post-processor.
#
#-----------------------------------------------------------------------
#
${APRUN} ./ncep_post < itag || print_err_msg_exit "\
Call to executable to run post for forecast hour $fhr returned with non-
zero exit code."
#
domain=${domain:-conus}
if [ ${domain:-conus} = conus ]
then
gridspecs="lambert:262.5:38.5:38.5 237.280:1799:3000 21.138:1059:3000"
elif [ $domain = "ak" ]
then
gridspecs="nps:210:60 185.5:825:5000 44.8:603:5000"
elif [ $domain = pr ]
then
gridspecs="latlon 283.41:340:.045 13.5:208:.045"
elif [ $domain = hi  ]
then
gridspecs="latlon 197.65:223:.045 16.4:170:.045"
elif [ $domain = guam  ]
then
gridspecs="latlon 141.0:223:.045 11.7:170:.045"
fi

compress_type=c3
WGRIB2=wgrib2 #clt
if [ $fhr -eq 00 ] ; then
  ${WGRIB2} BGDAWP${fhr}.${tmmark} | grep -F -f ${PARMfv3}/nam_nests.hiresf_inst.txt | grep ':anl:' | ${WGRIB2} -i -grib inputs.grib${domain}_inst BGDAWP${fhr}.${tmmark}
  ${WGRIB2} inputs.grib${domain}_inst -set_bitmap 1 -set_grib_type ${compress_type} \
    -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
    -new_grid_interpolation neighbor \
    -new_grid ${gridspecs} ${domain}${RUN}.f${fhr}.${tmmark}.inst
else
  ${WGRIB2} BGDAWP${fhr}.${tmmark} | grep -F -f ${PARMfv3}/nam_nests.hiresf_inst.txt | grep 'hour fcst' | ${WGRIB2} -i -grib inputs.grib${domain}_inst BGDAWP${fhr}.${tmmark}
  ${WGRIB2} inputs.grib${domain}_inst -set_bitmap 1 -set_grib_type ${compress_type} \
    -new_grid_winds grid -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
    -new_grid_interpolation neighbor \
    -new_grid ${gridspecs} ${domain}${RUN}.f${fhr}.${tmmark}.inst
fi

${WGRIB2} BGDAWP${fhr}.${tmmark} | grep -F -f ${PARMfv3}/nam_nests.hiresf_nn.txt | ${WGRIB2} -i -grib inputs.grib${domain} BGDAWP${fhr}.${tmmark}
${WGRIB2} inputs.grib${domain} -new_grid_vectors "UGRD:VGRD:USTM:VSTM" -submsg_uv inputs.grib${domain}.uv
${WGRIB2} BGDAWP${fhr}.${tmmark} -match ":(APCP|WEASD|SNOD):" -grib inputs.grib${domain}.uv_budget

${WGRIB2} inputs.grib${domain}.uv -set_bitmap 1 -set_grib_type ${compress_type} \
  -new_grid_winds grid -new_grid_interpolation neighbor -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
  -new_grid ${gridspecs} ${domain}${RUN}.f${fhr}.${tmmark}.uv
${WGRIB2} ${domain}${RUN}.f${fhr}.${tmmark}.uv -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
  -submsg_uv ${domain}${RUN}.f${fhr}.${tmmark}.nn

${WGRIB2} inputs.grib${domain}.uv_budget -set_bitmap 1 -set_grib_type ${compress_type} \
  -new_grid_winds grid -new_grid_interpolation budget \
  -new_grid ${gridspecs} ${domain}${RUN}.f${fhr}.${tmmark}.budget
cat ${domain}${RUN}.f${fhr}.${tmmark}.nn ${domain}${RUN}.f${fhr}.${tmmark}.budget ${domain}${RUN}.f${fhr}.${tmmark}.inst > ${domain}${RUN}.f${fhr}.${tmmark}

export err=$?; err_chk


# Generate files for FFaIR

#${WGRIB2} BGDAWP${fhr}.${tmmark} | grep -F -f ${PARMfv3}/nam_nests.hiresf_ffair.txt | ${WGRIB2} -i -grib inputs.grib${domain}_ffair BGDAWP${fhr}.${tmmark}
#${WGRIB2} inputs.grib${domain}_ffair -new_grid_vectors "UGRD:VGRD:USTM:VSTM" -submsg_uv inputs.grib${domain}.uv_ffair
#${WGRIB2} inputs.grib${domain}.uv_ffair -set_bitmap 1 -set_grib_type ${compress_type} \
#  -new_grid_winds grid -new_grid_interpolation neighbor -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
#  -new_grid ${gridspecs} ${domain}${RUN}.f${fhr}.${tmmark}.uv_ffair
#${WGRIB2} ${domain}${RUN}.f${fhr}.${tmmark}.uv_ffair -new_grid_vectors "UGRD:VGRD:USTM:VSTM" \
#  -submsg_uv ${domain}${RUN}.f${fhr}.${tmmark}.ffair
#cat ${domain}${RUN}.f${fhr}.${tmmark}.ffair ${domain}${RUN}.f${fhr}.${tmmark}.budget > ${domain}${RUN}.f${fhr}.${tmmark}.ffair

#export err=$?; err_chk
#thinkdeb
COMOUT=/scratch1/NCEPDEV/stmp2/Ting.Lei/com/$envir
mkdir -p $COMOUT
if [ ${SENDCOM:-YES} = YES ]
then
  if [ $tmmark = tm00 ] ; then
    mv ${domain}${RUN}.f${fhr}.${tmmark} ${COMOUT}/${RUN}.t${CYC}z.${domain:+${domain}.}f${fhr}.${memchar:+${memchar}.}grib2
#    mv ${domain}${RUN}.f${fhr}.${tmmark}.ffair ${COMOUT}/${RUN}.t${cyc}z.${domain}.ffair.f${fhr}.grib2
    mv BGDAWP${fhr}.${tmmark} ${COMOUT}/${RUN}.t${CYC}z.${domain+${domain}.}natprs.f${fhr}.${memchar:+${memchar}.}grib2
    mv BGRD3D${fhr}.${tmmark} ${COMOUT}/${RUN}.t${CYC}z.${domain+${domain}.}natlev.f${fhr}.${memchar:+${memchar}.}grib2
  else
    mv ${domain}${RUN}.f${fhr}.${tmmark} ${COMOUT}/${RUN}.t${CYC}z.${domain+${domain}.}f${fhr}.${tmmark}..${memchar:+${memchar}.}grib2
    mv BGDAWP${fhr}.${tmmark} ${COMOUT}/${RUN}.t${CYC}z.${domain+${domain}.}natprs.f${fhr}.${tmmark}.${memchar:+${memchar}.}grib2
    mv BGRD3D${fhr}.${tmmark} ${COMOUT}/${RUN}.t${CYC}z.${domain+${domain}.}natlev.f${fhr}.${tmmark}.${memchar:+${memchar}.}grib2
  fi
fi

echo done > ${INPUT_DATA_DIR}/postdone${fhr}.${tmmark}

exit
print_info_msg "
========================================================================
Post-processing for forecast hour $fhr completed successfully.

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

