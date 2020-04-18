#!/bin/bash -l
set -x

module load  rocoto/1.3.1
rocotorun -v 10 -w /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.xml -d /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/tl-fork_unified-workflow/expt_dirs/test4tl_emc/dev.db 
exit
rocotoboot -v 10 -w /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/unified-regional_workflow/expt_dirs/test4emc/dev-FV3SAR_wflow.xml -d /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/unified-regional_workflow/expt_dirs/test4emc/dev-FV3SAR_wflow.db -c  202003180000 -t make_ics 

exit
rocotoboot -v 10 -w /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/unified-regional_workflow/expt_dirs/test4emc/FV3SAR_wflow.xml -d /scratch2/NCEPDEV/fv3-cam/Ting.Lei/dr-regional-workflow/unified-regional_workflow/expt_dirs/test4emc/FV3SAR_wflow.db -c  202003180000 -t make_grid
