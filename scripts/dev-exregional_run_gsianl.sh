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
set -xu
  export OMP_NUM_THREADS=${OMP_THREADS:-${OMP_NUM_THREADS:-2}}
  export KMP_STACKSIZE=1024m
  export KMP_AFFINITY=disabled

case $MACHINE in
#
"WCOSS_C" | "WCOSS")
#

  if [ "${USE_CCPP}" = "TRUE" ]; then
  
# Needed to change to the experiment directory because the module files
# for the CCPP-enabled version of FV3 have been copied to there.

    cd_vrfy ${CYCLE_DIR}
  
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

#clt  ulimit -s unlimited
#clt  ulimit -a
  APRUN="mpirun -l -np ${PE_MEMBER01}"
  ;;
#
"THEIA")
  

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
#clt  ulimit -s unlimited
#clt  ulimit -a
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
#----------------------------

if [ $tmmark = tm06 ] ; then
  ens_nstarthr="06"  # from tm12 to tm06
else
  ens_nstarthr="01"  # from tm06 to tm05 and so on
fi

cd_vrfy ${DATA}

#
# Set variables used in script
export endianness=Big_Endian
#   ncp is cp replacement, currently keep as /bin/cp
ncp=/bin/cp



# Run gsi under Parallel Operating Environment (poe) on NCEP IBM


export HYB_ENS=".true."
export HX_ONLY=${HX_ONLY:-FALSE}

DOHYBVAR=${DOHYBVAR:-"YES"}
#DOHYBVAR="NO"  #thinkdeb ${DOHYBVAR:-"YES"}
#export HYB_ENS=".false." #cltthink
if [[ ${HX_ONLY} = "TRUE" ]]; then
DOHYBVAR=NO
export HYB_ENS=".false."

fi
regional_ensemble_option=${regional_ensemble_option:-1}
export nens=${nens:-81}
export nens_gfs=${nens_gfs:-$nens}
export nens_fv3sar=${nens_fv3sar:-$nens}
export l_both_fv3sar_gfs_ens=${l_both_fv3sar_gfs_ens:-.false.}
if [[ $DOHYBVAR = "YES" ]]; then 

 if [[ $regional_ensemble_option -eq 1 ||  $l_both_fv3sar_gfs_ens = '.true.' ]]; then
# We expect 81 total files to be present (80 enkf + 1 mean)

    # Not using FGAT or 4DEnVar, so hardwire nhr_assimilation to 3
    export nhr_assimilation=03
    ##typeset -Z2 nhr_assimilation

    if [ ${l_use_own_glb_ensemble:-.true.} = .true. ] ;then
    python $UTIL/getbest_EnKF_FV3GDAS.py -v $vlddate --exact=no --minsize=${nens_gfs} -d ${COMINgfs}/enkfgdas -o filelist${nhr_assimilation} --o3fname=gfs_sigf${nhr_assimilation} --gfs_nemsio=yes
#cltthink      if [[ $l_both_fv3sar_gfs_ens = ".true."  ]]; then
#cltthink        sed '1d;$d' filelist${nhr_assimilation} > d.txt  #don't use the ensemble mean
#cltthink        cp d.txt filelist${nhr_assimilation}
#cltthink      fi
    ####python $UTIL/getbest_EnKF.py -v $vlddate --exact=no --minsize=${nens} -d ${COMINgfs}/enkf -o filelist${nhr_assimilation} --o3fname=gfs_sigf${nhr_assimilation} --gfs_nemsio=yes

    #Check to see if ensembles were found
    numfiles=`cat filelist03 | wc -l`
    cp filelist${nhr_assimilation} $COMOUT/${RUN}.t${CYCrun}z.filelist03.${tmmark}
    else
    cp  $COMOUT_ctrl/${RUN}.t${CYCrun}z.filelist03.${tmmark} tmp_filelist${nhr_assimilation}
        glb_dir=$(dirname $(head -1 tmp_filelist${nhr_assimilation})) 
        echo glbdir is $glb_dir 
        ls $glb_dir 
        if [ !  -d $glb_dir  ]; then
# use different delimiter to handle the slash in the path names
        sed  "s_${COMINgfs}_${global_ens_dir_backup}_g" tmp_filelist${nhr_assimilation} >filelist${nhr_assimilation}
        else
         cp tmp_filelist${nhr_assimilation} filelist${nhr_assimilation}
        fi
    fi
         
       if [[ $regional_ensemble_option -eq 1  ]]; then
        if [ $numfiles -ne $nens_gfs ]; then
          echo "Ensembles not found - turning off HYBENS!"
          export HYB_ENS=".false."
        else
          # we have 81 files, figure out if they are all the right size
          # if not, set HYB_ENS=false
          . $UTIL/check_enkf_size.sh
        fi
          nens_gfs=`cat filelist03 | wc -l`
          nens=$nens_gfs
        fi

        echo "HYB_ENS=$HYB_ENS" > $COMOUT/${RUN}.t${CYCrun}z.hybens.${tmmark}
     fi
     if [[ $regional_ensemble_option -eq 5 ]]; then
       for imem in $(seq 1 $nens_fv3sar ); do
             memchar="mem"$(printf %03i $imem)
#        cp ${COMIN_GES_ENS}/$memchar/${PDY}.${CYC}0000.${memstr}fv_core.res.tile1.nc fv3SAR01_${memchar}-fv3_dynvars
         cp ${COMIN_GES_ENS}/$memchar/${PDY}.${CYC}0000.${memstr}fv_core.res.tile1.nc fv3SAR${ens_nstarthr}_ens_${memchar}-fv3_dynvars
         cp ${COMIN_GES_ENS}/$memchar/${PDY}.${CYC}0000.${memstr}fv_tracer.res.tile1.nc fv3SAR${ens_nstarthr}_ens_${memchar}-fv3_tracer
         done

     fi

 
fi  # DO_HYB_ENS

# Set parameters
export USEGFSO3=.false.
export nhr_assimilation=3
export vs=1.
export fstat=.false.
export i_gsdcldanal_type=0
use_gfs_nemsio=.true.,

export SETUP_part1=${SETUP_part1:-"miter=2,niter(1)=50,niter(2)=50"}
if [ ${l_both_fv3sar_gfs_ens:-.false.} = ".true." ]; then  #regular  run
export HybParam_part2="l_both_fv3sar_gfs_ens=$l_both_fv3sar_gfs_ens,n_ens_gfs=$nens_gfs,n_ens_fv3sar=$nens_fv3sar,"
else
export HybParam_part2=" "

fi


# Make gsi namelist
echo "current dir is" 
pwd 
cat << EOF > gsiparm.anl

 &SETUP
   $SETUP_part1,niter_no_qc(1)=20,
   write_diag(1)=.true.,write_diag(2)=.false.,write_diag(3)=.true.,
   gencode=78,qoption=2,
   factqmin=0.0,factqmax=0.0,
   iguess=-1,use_gfs_ozone=${USEGFSO3},
   oneobtest=.false.,retrieval=.false.,
   nhr_assimilation=${nhr_assimilation},l_foto=.false.,
   use_pbl=.false.,gpstop=30.,
   use_gfs_nemsio=.true.,
   print_diag_pcg=.true.,
   newpc4pred=.true., adp_anglebc=.true., angord=4,
   passive_bc=.true., use_edges=.false., emiss_bc=.true.,
   diag_precon=.true., step_start=1.e-3,
   lread_obs_save=${lread_obs_save:-".true."}, 
   lread_obs_skip=${lread_obs_skip:-".false."}, 
   ens_nstarthr=$ens_nstarthr,
 /
 &GRIDOPTS
   fv3_regional=.true.,grid_ratio_fv3_regional=3.0,nvege_type=20,
 /
 &BKGERR
   hzscl=0.373,0.746,1.50,
   vs=${vs},bw=0.,fstat=${fstat},
 /
 &ANBKGERR
   anisotropic=.false.,
 /
 &JCOPTS
 /
 &STRONGOPTS
   nstrong=0,
 /
 &OBSQC
   dfact=0.75,dfact1=3.0,noiqc=.false.,c_varqc=0.02,
   vadfile='prepbufr',njqc=.false.,vqc=.true.,
   aircraft_t_bc=.true.,biaspredt=1000.0,upd_aircraft=.true.,cleanup_tail=.true.,
 /
 &OBS_INPUT
   dmesh(1)=120.0,time_window_max=1.5,ext_sonde=.true.,
 /
OBS_INPUT::
!  dfile          dtype       dplat       dsis                  dval    dthin  dsfcalc
   prepbufr       ps          null        ps                  0.0     0     0
   prepbufr       t           null        t                   0.0     0     0
   prepbufr_profl t           null        t                   0.0     0     0
   prepbufr       q           null        q                   0.0     0     0
   prepbufr_profl q           null        q                   0.0     0     0
   prepbufr       pw          null        pw                  0.0     0     0
   prepbufr       uv          null        uv                  0.0     0     0
   prepbufr_profl uv          null        uv                  0.0     0     0
   satwndbufr     uv          null        uv                  0.0     0     0
   prepbufr       spd         null        spd                 0.0     0     0
   prepbufr       dw          null        dw                  0.0     0     0
   l2rwbufr       rw          null        l2rw                0.0     0     0
   prepbufr       sst         null        sst                 0.0     0     0
   nsstbufr       sst         nsst        sst                 0.0     0     0
   gpsrobufr      gps_bnd     null        gps                 0.0     0     0
   hirs4bufr      hirs4       metop-a     hirs4_metop-a       0.0     1     1
   gimgrbufr      goes_img    g11         imgr_g11            0.0     1     0
   gimgrbufr      goes_img    g12         imgr_g12            0.0     1     0
   airsbufr       airs        aqua        airs281SUBSET_aqua  0.0     1     1
   amsuabufr      amsua       n15         amsua_n15           0.0     1     1
   amsuabufr      amsua       n18         amsua_n18           0.0     1     1
   amsuabufr      amsua       metop-a     amsua_metop-a       0.0     1     1
   airsbufr       amsua       aqua        amsua_aqua          0.0     1     1
   mhsbufr        mhs         n18         mhs_n18             0.0     1     1
   mhsbufr        mhs         metop-a     mhs_metop-a         0.0     1     1
   ssmitbufr      ssmi        f14         ssmi_f14            0.0     1     0
   ssmitbufr      ssmi        f15         ssmi_f15            0.0     1     0
   amsrebufr      amsre_low   aqua        amsre_aqua          0.0     1     0
   amsrebufr      amsre_mid   aqua        amsre_aqua          0.0     1     0
   amsrebufr      amsre_hig   aqua        amsre_aqua          0.0     1     0
   ssmisbufr      ssmis       f16         ssmis_f16           0.0     1     0
   ssmisbufr      ssmis       f17         ssmis_f17           0.0     1     0
   ssmisbufr      ssmis       f18         ssmis_f18           0.0     1     0
   ssmisbufr      ssmis       f19         ssmis_f19           0.0     1     0
   gsnd1bufr      sndrd1      g12         sndrD1_g12          0.0     1     0
   gsnd1bufr      sndrd2      g12         sndrD2_g12          0.0     1     0
   gsnd1bufr      sndrd3      g12         sndrD3_g12          0.0     1     0
   gsnd1bufr      sndrd4      g12         sndrD4_g12          0.0     1     0
   gsnd1bufr      sndrd1      g11         sndrD1_g11          0.0     1     0
   gsnd1bufr      sndrd2      g11         sndrD2_g11          0.0     1     0
   gsnd1bufr      sndrd3      g11         sndrD3_g11          0.0     1     0
   gsnd1bufr      sndrd4      g11         sndrD4_g11          0.0     1     0
   gsnd1bufr      sndrd1      g13         sndrD1_g13          0.0     1     0
   gsnd1bufr      sndrd2      g13         sndrD2_g13          0.0     1     0
   gsnd1bufr      sndrd3      g13         sndrD3_g13          0.0     1     0
   gsnd1bufr      sndrd4      g13         sndrD4_g13          0.0     1     0
   iasibufr       iasi        metop-a     iasi616_metop-a     0.0     1     1
   omibufr        omi         aura        omi_aura            0.0     2     0
   hirs4bufr      hirs4       n19         hirs4_n19           0.0     1     1
   amsuabufr      amsua       n19         amsua_n19           0.0     1     1
   mhsbufr        mhs         n19         mhs_n19             0.0     1     1
   tcvitl         tcp         null        tcp                 0.0     0     0
   seviribufr     seviri      m08         seviri_m08          0.0     1     0
   seviribufr     seviri      m09         seviri_m09          0.0     1     0
   seviribufr     seviri      m10         seviri_m10          0.0     1     0
   hirs4bufr      hirs4       metop-b     hirs4_metop-b       0.0     1     1
   amsuabufr      amsua       metop-b     amsua_metop-b       0.0     1     1
   mhsbufr        mhs         metop-b     mhs_metop-b         0.0     1     1
   iasibufr       iasi        metop-b     iasi616_metop-b     0.0     1     1
   atmsbufr       atms        npp         atms_npp            0.0     1     0
   crisbufr       cris        npp         cris_npp            0.0     1     0
   gsnd1bufr      sndrd1      g14         sndrD1_g14          0.0     1     0
   gsnd1bufr      sndrd2      g14         sndrD2_g14          0.0     1     0
   gsnd1bufr      sndrd3      g14         sndrD3_g14          0.0     1     0
   gsnd1bufr      sndrd4      g14         sndrD4_g14          0.0     1     0
   gsnd1bufr      sndrd1      g15         sndrD1_g15          0.0     1     0
   gsnd1bufr      sndrd2      g15         sndrD2_g15          0.0     1     0
   gsnd1bufr      sndrd3      g15         sndrD3_g15          0.0     1     0
   gsnd1bufr      sndrd4      g15         sndrD4_g15          0.0     1     0
   oscatbufr      uv          null        uv                  0.0     0     0
   mlsbufr        mls30       aura        mls30_aura          0.0     0     0
   avhambufr      avhrr       metop-a     avhrr3_metop-a      0.0     1     0
   avhpmbufr      avhrr       n18         avhrr3_n18          0.0     1     0
   prepbufr       mta_cld     null        mta_cld             1.0     0     0     
   prepbufr       gos_ctp     null        gos_ctp             1.0     0     0     
   lgycldbufr     larccld     null        larccld             1.0     0     0
   lghtnbufr      lghtn       null        lghtn               1.0     0     0
::
 &SUPEROB_RADAR
   del_azimuth=5.,del_elev=.25,del_range=5000.,del_time=.5,elev_angle_max=5.,minnum=50,range_max=100000.,
   l2superob_only=.false.,
 /
 &LAG_DATA
 /
 &HYBRID_ENSEMBLE
   l_hyb_ens=$HYB_ENS,
   n_ens=$nens,
   uv_hyb_ens=.true.,
   beta_s0=0.25,
   s_ens_h=110,
   s_ens_v=3,
   generate_ens=.false.,
   regional_ensemble_option=${regional_ensemble_option},
   aniso_a_en=.false.,
   nlon_ens=0,
   nlat_ens=0,
   jcap_ens=574,
   l_ens_in_diff_time=.true.,
   jcap_ens_test=0,
   full_ensemble=.true.,pwgtflg=.true.,
   ensemble_path="",
   ${HybParam_part2}
 /
 &RAPIDREFRESH_CLDSURF
   i_gsdcldanal_type=${i_gsdcldanal_type},
   dfi_radar_latent_heat_time_period=20.0,
   l_use_hydroretrieval_all=.false.,
   metar_impact_radius=10.0,
   metar_impact_radius_lowCloud=4.0,
   l_gsd_terrain_match_surfTobs=.false.,
   l_sfcobserror_ramp_t=.false.,
   l_sfcobserror_ramp_q=.false.,
   l_PBL_pseudo_SurfobsT=.false.,
   l_PBL_pseudo_SurfobsQ=.false.,
   l_PBL_pseudo_SurfobsUV=.false.,
   pblH_ration=0.75,
   pps_press_incr=20.0,
   l_gsd_limit_ocean_q=.false.,
   l_pw_hgt_adjust=.false.,
   l_limit_pw_innov=.false.,
   max_innov_pct=0.1,
   l_cleanSnow_WarmTs=.false.,
   r_cleanSnow_WarmTs_threshold=5.0,
   l_conserve_thetaV=.false.,
   i_conserve_thetaV_iternum=3,
   l_cld_bld=.false.,
   cld_bld_hgt=1200.0,
   build_cloud_frac_p=0.50,
   clear_cloud_frac_p=0.1,
   iclean_hydro_withRef=1,
   iclean_hydro_withRef_allcol=0,
 /
 &CHEM
 /
 &SINGLEOB_TEST
 /
 &NST
 /

EOF

anavinfo=$PARMfv3/anavinfo_fv3_64
berror=$fixgsi/$endianness/nam_glb_berror.f77.gcv
emiscoef_IRwater=$fixcrtm/Nalli.IRwater.EmisCoeff.bin
emiscoef_IRice=$fixcrtm/NPOESS.IRice.EmisCoeff.bin
emiscoef_IRland=$fixcrtm/NPOESS.IRland.EmisCoeff.bin
emiscoef_IRsnow=$fixcrtm/NPOESS.IRsnow.EmisCoeff.bin
emiscoef_VISice=$fixcrtm/NPOESS.VISice.EmisCoeff.bin
emiscoef_VISland=$fixcrtm/NPOESS.VISland.EmisCoeff.bin
emiscoef_VISsnow=$fixcrtm/NPOESS.VISsnow.EmisCoeff.bin
emiscoef_VISwater=$fixcrtm/NPOESS.VISwater.EmisCoeff.bin
emiscoef_MWwater=$fixcrtm/FASTEM6.MWwater.EmisCoeff.bin
aercoef=$fixcrtm/AerosolCoeff.bin
cldcoef=$fixcrtm/CloudCoeff.bin
#satinfo=$fixgsi/nam_regional_satinfo.txt
satinfo=$PARMfv3/fv3sar_satinfo.txt
scaninfo=$fixgsi/global_scaninfo.txt
satangl=$fixgsi/nam_global_satangbias.txt
atmsbeamdat=$fixgsi/atms_beamwidth.txt
pcpinfo=$fixgsi/nam_global_pcpinfo.txt
ozinfo=$fixgsi/nam_global_ozinfo.txt
errtable=$fixgsi/nam_errtable.r3dv
convinfo=$fixgsi/nam_regional_convinfo.txt
mesonetuselist=$fixgsi/nam_mesonet_uselist.txt
stnuselist=$fixgsi/nam_mesonet_stnuselist.txt

# Copy executable and fixed files to $DATA

$ncp $anavinfo ./anavinfo
$ncp $berror   ./berror_stats
$ncp $emiscoef_IRwater ./Nalli.IRwater.EmisCoeff.bin
$ncp $emiscoef_IRice ./NPOESS.IRice.EmisCoeff.bin
$ncp $emiscoef_IRsnow ./NPOESS.IRsnow.EmisCoeff.bin
$ncp $emiscoef_IRland ./NPOESS.IRland.EmisCoeff.bin
$ncp $emiscoef_VISice ./NPOESS.VISice.EmisCoeff.bin
$ncp $emiscoef_VISland ./NPOESS.VISland.EmisCoeff.bin
$ncp $emiscoef_VISsnow ./NPOESS.VISsnow.EmisCoeff.bin
$ncp $emiscoef_VISwater ./NPOESS.VISwater.EmisCoeff.bin
$ncp $emiscoef_MWwater ./FASTEM6.MWwater.EmisCoeff.bin
$ncp $aercoef  ./AerosolCoeff.bin
$ncp $cldcoef  ./CloudCoeff.bin
$ncp $satangl  ./satbias_angle
$ncp $atmsbeamdat  ./atms_beamwidth.txt
$ncp $satinfo  ./satinfo
$ncp $scaninfo ./scaninfo
$ncp $pcpinfo  ./pcpinfo
$ncp $ozinfo   ./ozinfo
$ncp $convinfo ./convinfo
$ncp $errtable ./errtable
$ncp $mesonetuselist ./mesonetuselist
$ncp $stnuselist ./mesonet_stnuselist
$ncp $fixgsi/prepobs_prep.bufrtable ./prepobs_prep.bufrtable



# Copy CRTM coefficient files based on entries in satinfo file
for file in `awk '{if($1!~"!"){print $1}}' ./satinfo | sort | uniq` ;do
    $ncp $fixcrtm/${file}.SpcCoeff.bin ./
    $ncp $fixcrtm/${file}.TauCoeff.bin ./
done

# If requested, link (and if tarred, de-tar obsinput.tar) into obs_input.* files
if [ ${USE_SELECT:-NO} = "YES" ]; then
   rm obs_input.*
   nl=$(file $SELECT_OBS | cut -d: -f2 | grep tar | wc -l)
   if [ $nl -eq 1 ]; then
      rm obsinput.tar
      $NLN $SELECT_OBS obsinput.tar
      tar -xvf obsinput.tar
      rm obsinput.tar
   else
      for filetop in $(ls $SELECT_OBS/obs_input.*); do
         fileloc=$(basename $filetop)
         $NLN $filetop $fileloc
      done
   fi
fi





###export nmmb_nems_obs=${COMINnam}/nam.${PDYrun}
export nmmb_nems_obs=${COMINrap}/rap.${PDYa}

export nmmb_nems_bias=${COMINbias}

if [ ${USE_SELECT:-NO} != "YES" ]; then  #regular  run
   if [ ! -d $nmmb_nems_obs  ]; then
     export nmmb_nems_obs=${COMINrap_user}/rap.${PDYa}
     if [ ! -d $nmmb_nems_obs  ]; then
       echo "there are no obs needed, exit"
       exit 250
     fi
   fi
     
# Copy observational data to $tmpdir
$ncp $nmmb_nems_obs/rap.t${cya}z.prepbufr.tm00  ./prepbufr
$ncp $nmmb_nems_obs/rap.t${cya}z.prepbufr.acft_profiles.tm00 prepbufr_profl
$ncp $nmmb_nems_obs/rap.t${cya}z.satwnd.tm00.bufr_d ./satwndbufr
$ncp $nmmb_nems_obs/rap.t${cya}z.1bhrs3.tm00.bufr_d ./hirs3bufr
$ncp $nmmb_nems_obs/rap.t${cya}z.1bhrs4.tm00.bufr_d ./hirs4bufr
$ncp $nmmb_nems_obs/rap.t${cya}z.mtiasi.tm00.bufr_d ./iasibufr
$ncp $nmmb_nems_obs/rap.t${cya}z.1bamua.tm00.bufr_d ./amsuabufr
$ncp $nmmb_nems_obs/rap.t${cya}z.esamua.tm00.bufr_d ./amsuabufrears
$ncp $nmmb_nems_obs/rap.t${cya}z.1bamub.tm00.bufr_d ./amsubbufr
$ncp $nmmb_nems_obs/rap.t${cya}z.1bmhs.tm00.bufr_d  ./mhsbufr
$ncp $nmmb_nems_obs/rap.t${cya}z.goesnd.tm00.bufr_d ./gsnd1bufr
$ncp $nmmb_nems_obs/rap.t${cya}z.airsev.tm00.bufr_d ./airsbufr
$ncp $nmmb_nems_obs/rap.t${cya}z.cris.tm00.bufr_d ./crisbufr
$ncp $nmmb_nems_obs/rap.t${cya}z.atms.tm00.bufr_d ./atmsbufr
$ncp $nmmb_nems_obs/rap.t${cya}z.sevcsr.tm00.bufr_d ./seviribufr
$ncp $nmmb_nems_obs/rap.t${cya}z.radwnd.tm00.bufr_d ./radarbufr
$ncp $nmmb_nems_obs/rap.t${cya}z.nexrad.tm00.bufr_d ./l2rwbufr
fi

export GDAS_SATBIAS=NO

if [ $GDAS_SATBIAS = NO ] ; then

  if [ $tmmark = "tm06" ]; then  #regular  run
       $ncp $nmmb_nems_bias/${RUN}.t${cyctm06}z.satbias.tm01 ./satbias_in
       err1=$?
       if [ $err1 -ne 0 ] ; then
	  cp $GESROOT_HOLD/satbias_in ./satbias_in
	fi

	$ncp $nmmb_nems_bias/${RUN}.t${cyctm06}z.satbias_pc.tm01 ./satbias_pc
	err2=$?
	if [ $err2 -ne 0 ] ; then
	  cp $GESROOT_HOLD/satbias_pc ./satbias_pc
	fi

	$ncp $nmmb_nems_bias/${RUN}.t${cyctm06}z.radstat.tm01    ./radstat.gdas
	err3=$?
	if [ $err3 -ne 0 ] ; then
	  cp $GESROOT_HOLD/radstat.nam ./radstat.gdas
	fi

  else
	$ncp $nmmb_nems_bias/${RUN}.t${CYCrun}z.satbias.${tmmark_prev} ./satbias_in
	err1=$?
	if [ $err1 -ne 0 ] ; then
	  cp $GESROOT_HOLD/satbias_in ./satbias_in
	fi
	$ncp $nmmb_nems_bias/${RUN}.t${CYCrun}z.satbias_pc.${tmmark_prev} ./satbias_pc
	err2=$?
	if [ $err2 -ne 0 ] ; then
	  cp $GESROOT_HOLD/satbias_pc ./satbias_pc
	fi
	$ncp $nmmb_nems_bias/${RUN}.t${CYCrun}z.radstat.${tmmark_prev}    ./radstat.gdas
	err3=$?
	if [ $err3 -ne 0 ] ; then
	  cp $GESROOT_HOLD/radstat.nam ./radstat.gdas
	fi
   fi
else

cp $GESROOT_HOLD/gdas.satbias_out ./satbias_in
cp $GESROOT_HOLD/gdas.satbias_pc ./satbias_pc
cp $GESROOT_HOLD/gdas.radstat_out ./radstat.gdas


fi

#Aircraft bias corrections always cycled through 6-h DA
 if [ $tmmark = "tm06" ]; then  #regular  run
   $ncp $MYGDAS/gdas.t${cya}z.abias_air ./aircftbias_in
    err4=$?
#cltthinkto    if [ $err4 -ne 0 ] ; then
#clt       $ncp $GBGDAS/gdas.t${cya}z.abias_air ./aircftbias_in
#clt     fi

  else
    $ncp $nmmb_nems_bias/${RUN}.t${CYCrun}z.abias_air.${tmmark_prev} ./aircftbias_in
    err4=$?
  fi
if [ $err4 -ne 0 ] ; then
  cp $GESROOT_HOLD/gdas.airbias ./aircftbias_in
fi

#clt cp $COMINrtma/rtma2p5.${PDYa}/rtma2p5.t${cya}z.w_rejectlist ./w_rejectlist
#clt cp $COMINrtma/rtma2p5.${PDYa}/rtma2p5.t${cya}z.t_rejectlist ./t_rejectlist
#clt cp $COMINrtma/rtma2p5.${PDYa}/rtma2p5.t${cya}z.p_rejectlist ./p_rejectlist
#clt cp $COMINrtma/rtma2p5.${PDYa}/rtma2p5.t${cya}z.q_rejectlist ./q_rejectlist
#clt export ctrlstr=${ctrlstr:-control}

export fv3_case=$GUESSdir
echo "thinkdeb pwd is " `pwd`

#  INPUT FILES FV3 NEST (single tile)

alias cp 
#   This file contains time information
cp $fv3_case/${PDY}.${CYC}0000.coupler.res coupler.res
ls -l  $fv3_case/${PDY}.${CYC}0000.coupler.res coupler.res
ls -l coupler.res
#   This file contains vertical weights for defining hybrid volume hydrostatic pressure interfaces 
cp $fv3_case/${PDY}.${CYC}0000.fv_core.res.nc fv3_akbk
#   This file contains horizontal grid information
cp $fv3_case/grid_spec.nc fv3_grid_spec
cp $fv3_case/${PDY}.${CYC}0000.sfc_data.nc fv3_sfcdata
#   This file contains 3d fields u,v,w,dz,T,delp, and 2d sfc geopotential phis
ctrlstrname=${ctrlstr:+_${ctrlstr}_}
   BgFile4dynvar=${BgFile4dynvar:-$fv3_case/${PDY}.${CYC}0000.${ctrlstrname}fv_core.res.tile1.nc}
   BgFile4tracer=${BgFile4tracer:-$fv3_case/${PDY}.${CYC}0000.${ctrlstrname}fv_tracer.res.tile1.nc}
cp $BgFile4dynvar fv3_dynvars
#   This file contains 3d tracer fields sphum, liq_wat, o3mr
cp $BgFile4tracer fv3_tracer
#   This file contains surface fields (vert dims of 3, 4, and 63)

export pgm=`basename $gsiexec`
$ncp $gsiexec ./regional_gsi.x

###mpirun -l -n 240 $gsiexec < gsiparm.anl > $pgmout 2> stderr
#mpirun -l -n 240 gsi.x < gsiparm.anl > $pgmout 2> stderr
srun --ntasks=240 --label regional_gsi.x  < gsiparm.anl > stdout 2> stderr  #clt  || print_err_msg_exit "\
export err=$?
report-mem
#Call to executable to run gsi analysis with nonzero exit 
#code."
# If requested, create obsinput tarball from obs_input.* files
if [ ${RUN_SELECT:-NO} = "YES" ]; then
  echo $(date) START tar obs_input >&2
  rm obsinput.tar
  $NLN $SELECT_OBS obsinput.tar
  tar -cvf obsinput.tar obs_input.*
  chmod 750 $SELECT_OBS
#cltthink   ${CHGRP_CMD} $SELECT_OBS
  rm obsinput.tar
  echo $(date) END tar obs_input >&2
fi



mv fort.201 fit_p1
mv fort.202 fit_w1
mv fort.203 fit_t1
mv fort.204 fit_q1
mv fort.205 fit_pw1
mv fort.207 fit_rad1
mv fort.209 fit_rw1
if [[ $HX_ONLY != TRUE ]];then
cat fit_p1 fit_w1 fit_t1 fit_q1 fit_pw1 fit_rad1 fit_rw1 > $COMOUT/${RUN}.t${CYCrun}z.${ctrlstr}fits.${tmmark}
cat fort.208 fort.210 fort.211 fort.212 fort.213 fort.220 > $COMOUT/${RUN}.t${CYCrun}z.${ctrlstr}fits2.${tmmark}

#clt cp satbias_out $GESROOT_HOLD/satbias_in
 cp satbias_out $COMOUT/${RUN}.t${CYCrun}z.satbias.${tmmark}
#cltthink cp satbias_pc.out $GESROOT_HOLD/satbias_pc
 cp satbias_pc.out $COMOUT/${RUN}.t${CYCrun}z.satbias_pc.${tmmark}

 cp aircftbias_out $COMOUT/${RUN}.t${CYCrun}z.abias_air.${tmmark}
#cp aircftbias_out $GESROOT_HOLD/gdas.airbias
fi 

RADSTAT=${COMOUT}/${RUN}.t${CYCrun}z.${ctrlstr+${ctrlstr}_}radstat.${tmmark}
CNVSTAT=${COMOUT}/${RUN}.t${CYCrun}z.${ctrlstr+${ctrlstr}_}cnvstat.${tmmark}

# Set up lists and variables for various types of diagnostic files.
ntype=1

diagtype[0]="conv"
diagtype[1]="hirs2_n14 msu_n14 sndr_g08 sndr_g11 sndr_g12 sndr_g13 sndr_g08_prep sndr_g11_prep sndr_g12_prep sndr_g13_prep sndrd1_g11 sndrd2_g11 sndrd3_g11 sndrd4_g11 sndrd1_g12 sndrd2_g12 sndrd3_g12 sndrd4_g12 sndrd1_g13 sndrd2_g13 sndrd3_g13 sndrd4_g13 sndrd1_g14 sndrd2_g14 sndrd3_g14 sndrd4_g14 sndrd1_g15 sndrd2_g15 sndrd3_g15 sndrd4_g15 hirs3_n15 hirs3_n16 hirs3_n17 amsua_n15 amsua_n16 amsua_n17 amsub_n15 amsub_n16 amsub_n17 hsb_aqua airs_aqua amsua_aqua imgr_g08 imgr_g11 imgr_g12 imgr_g14 imgr_g15 ssmi_f13 ssmi_f14 ssmi_f15 hirs4_n18 hirs4_metop-a amsua_n18 amsua_metop-a mhs_n18 mhs_metop-a amsre_low_aqua amsre_mid_aqua amsre_hig_aqua ssmis_las_f16 ssmis_uas_f16 ssmis_img_f16 ssmis_env_f16 ssmis_las_f17 ssmis_uas_f17 ssmis_img_f17 ssmis_env_f17 ssmis_las_f18 ssmis_uas_f18 ssmis_img_f18 ssmis_env_f18 ssmis_las_f19 ssmis_uas_f19 ssmis_img_f19 ssmis_env_f19 ssmis_las_f20 ssmis_uas_f20 ssmis_img_f20 ssmis_env_f20 iasi_metop-a hirs4_n19 amsua_n19 mhs_n19 seviri_m08 seviri_m09 seviri_m10 cris_npp atms_npp hirs4_metop-b amsua_metop-b mhs_metop-b iasi_metop-b gome_metop-b"

diaglist[0]=listcnv
diaglist[1]=listrad

diagfile[0]=$CNVSTAT
diagfile[1]=$RADSTAT

numfile[0]=0
numfile[1]=0

# Set diagnostic file prefix based on lrun_subdirs variable
   prefix="pe*"

# Compress and tar diagnostic files.
if [[ $HX_ONLY != TRUE ]];then
loops="01 03"
else
loops="01 "
fi
for loop in $loops; do
   case $loop in
     01) string=ges;;
     03) string=anl;;
      *) string=$loop;;
   esac
   n=-1
   while [ $((n+=1)) -le $ntype ] ;do
      for type in `echo ${diagtype[n]}`; do
         count=`ls ${prefix}${type}_${loop}* | wc -l`
         if [ $count -gt 0 ]; then
            cat ${prefix}${type}_${loop}* > diag_${type}${ctrlstr+_${ctrlstr}_}${string}.${SDATE}
            echo "diag_${type}${ctrlstr+_${ctrlstr}_}${string}.${SDATE}*" >> ${diaglist[n]}
            numfile[n]=`expr ${numfile[n]} + 1`
         fi
      done
   done
done


#  compress diagnostic files
   for file in `ls diag_*${SDATE}`; do
      gzip $file
   done

# If requested, create diagnostic file tarballs
   n=-1
   while [ $((n+=1)) -le $ntype ] ;do
      TAROPTS="-uvf"
      if [ ! -s ${diagfile[n]} ]; then
         TAROPTS="-cvf"
      fi
      if [ ${numfile[n]} -gt 0 ]; then
         tar $TAROPTS ${diagfile[n]} `cat ${diaglist[n]}`
      fi
   done

#  Restrict CNVSTAT
   chmod 750 $CNVSTAT
   chgrp rstprod $CNVSTAT

if [[ $HX_ONLY != TRUE ]];then
if [ $tmmark != tm00 ] ; then 
echo 'do nothing for being now'
#  cp $RADSTAT ${GESROOT_HOLD}/radstat.nam
fi

# Put analysis files in ANLdir (defined in J-job)
mv fv3_akbk $ANLdir/${ctrlstr+_${ctrlstr}_}fv_core.res.nc
mv coupler.res $ANLdir/${ctrlstr+_${ctrlstr}_}coupler.res
mv fv3_dynvars $ANLdir/${ctrlstr+_${ctrlstr}_}fv_core.res.tile1.nc
mv fv3_tracer $ANLdir/${ctrlstr+_${ctrlstr}_}fv_tracer.res.tile1.nc
mv fv3_sfcdata $ANLdir/${ctrlstr+_${ctrlstr}_}sfc_data.nc
cp fv3_grid_spec $ANLdir/${ctrlstr+_${ctrlstr}_}fv3_grid_spec.nc
cp $COMOUT/gfsanl.tm12/gfs_ctrl.nc $ANLdir/.  #tothink
fi
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
gsi analysis  completed successfully!!!

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#clt ------------------------------------------------
{ restore_shell_opts; } > /dev/null 2>&1

