#!/bin/bash -l
set -x

module load  rocoto/1.3.1
rocotorewind -v 10 -w /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.xml -d /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.db -c 202004170000 -t  forecast_tm00 
rocotoboot -v 10 -w /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.xml -d /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.db -c 202004170000 -t  forecast_tm00 
exit
rocotoboot -v 10 -w /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.xml -d /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.db -c 202004170000 -t  run_post_init_fcst_fhr01 
exit
rocotorewind -v 10 -w /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.xml -d /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.db -c 202004170000 -t  analysis_tm00 
exit
exit
exit
exit
rocotoboo -v 10 -w /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.xml -d /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.db -c 202004170000 -t  chgres_fcstbndy_tm00 

rocotoboot -v 10 -w /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.xml -d /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.db -c 202004170000 -t  chgres_fcstbndy_tm00 
exit
rocotoboot -v 10 -w /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.xml -d /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.db -c 202004170000 -t  get_extrn_lbcs_tm00 
exit
rocotoboot -v 10 -w /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.xml -d /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.db -c 202004170000 -t  run_fcst 
exit
rocotoboot -v 10 -w /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/unified-regional_workflow/expt_dirs/test4emc/dev-FV3SAR_wflow.xml -d /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/unified-regional_workflow/expt_dirs/test4emc/dev-FV3SAR_wflow.db -c  202003180000 -t make_ics 

exit
rocotoboot -v 10 -w /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/unified-regional_workflow/expt_dirs/test4emc/FV3SAR_wflow.xml -d /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/unified-regional_workflow/expt_dirs/test4emc/FV3SAR_wflow.db -c  202003180000 -t make_grid
