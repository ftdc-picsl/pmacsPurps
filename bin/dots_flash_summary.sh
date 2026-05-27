#!/bin/bash


if [[ $# -lt 3 ]] ;then 
    echo "USAGE ./dots_flash_summary.sh <flash> <flash_dots_filename> <scriptsdir>"
    echo "outputs a file that contains summaries of output from c3d -lstat containing info about the flash image intensity"
    exit 1
fi


flash=$1
flash_dots=$2 
scriptsdir=$3

module load c3d


outfilename=`basename $flash | sed 's/rec-reorient_FLASH.nii.gz/rec-reorient_seg-cortexdots_desc-intensity_labelstats.tsv/'`
flash_dots_filename=`basename $flash_dots`

outfilepath=`echo $flash_dots | sed "s/$flash_dots_filename/$outfilename/"`

if [[ ! -f $outfilepath ]]; then
    c3d $flash $flash_dots -lstat | sed 's/Extent(Vox)/Extent_x Extent_y Extent_z/' | sed 's/^[[:blank:]]\+//g' | sed 's/[[:blank:]]\+/\t/g'  > $outfilepath 
fi
