#!/bin/ksh
set -aux

if [ $# -ne 10 ]; then
   echo "Usage: $0 resolution grid_dir orog_dir out_dir cd4 peak_fac max_slope n_del2_weak script_dir gtype "
   exit 1
fi
if [ $gtype = stretch ] || [ $gtype = regional ]; then
  stretch=$stretch_fac
else
  stretch=1.0
fi
export res=$1 
export griddir=$2
export orodir=$3
export outdir=$4
export script_dir=$9

export executable=$exec_dir/filter_topo
if [ ! -s $executable ]; then
  echo "executable does not exist"
  exit 1 
fi
export mosaic_grid=C${res}_mosaic.nc
export topo_file=oro.C${res}

if [ ! -s $outdir ]; then mkdir -p $outdir ;fi
cd $outdir ||exit 8

if [ $gtype = regional ]; then
#
# Make links instead of copying to avoid multiple copies of files.
#
#  cp $griddir/$mosaic_grid .
#  cp $griddir/C${res}_grid.tile7.nc .
  ln -fs --relative $griddir/$mosaic_grid $outdir/$mosaic_grid
  ln -fs --relative $griddir/C${res}_grid.tile7.nc $outdir/C${res}_grid.tile7.nc
#
# Don't link to the input orography file containing the data that is go-
# ing to be filtered because filter_topo will overwrite its input (un-
# filtered) orography file with the filtered orography.  Thus, creating
# a symlink to the input file would overwrite the unfiltered file in 
# orodir.  Instead, just copy the unfiltered file to outdir, where it 
# will be read as input and overwritten by the filtered data.
#
  cp $orodir/${topo_file}.tile7.nc .
else
  cp $griddir/$mosaic_grid .
  cp $griddir/C${res}_grid.tile?.nc .
  cp $orodir/${topo_file}.tile?.nc .
fi
cp $executable .

regional=.false.
if [ $gtype = regional ]; then
  regional=.true.
fi

cat > input.nml <<EOF
&filter_topo_nml
  grid_file = $mosaic_grid
  topo_file = $topo_file
  mask_field = "land_frac"    ! Defaults:
  cd4 = $5                    ! 0.15
  peak_fac =  $6              ! 1.0
  max_slope = $7              ! 0.12
  n_del2_weak = $8            ! 16
  regional = $regional 
  stretch_fac = $stretch
  /
EOF

$APRUN $executable

if [ $? -ne 0 ]; then
  echo "ERROR in running filter topography for C$res "
  exit 1
else
  echo "successfully running filter topography for C$res"
  exit 0
fi

exit
