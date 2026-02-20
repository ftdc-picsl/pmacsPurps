#!/bin/bash

if [[ $# -lt 7 ]]; then
    echo "./reslice_dots_to_flashreorient.sh <t2w_reorient> <t2w_reslice> <t2w_reslice_to_reorient> <t2w_reslice_dots> <flash_reorient> <flash_reorient_dots_out_filename> <scriptsdir>"

    exit 1
fi

module unload python
module unload greedy
module load greedy

t2w_reorient=$1
t2w_reslice=$2
t2w_reslice_to_reorient=$3
t2w_reslice_dots=$4
flash_reorient=$5
flash_reorient_dots=$6
scriptsdir=$7

if [[ -f $flash_reorient_dots ]] ; then
    echo "$flash_reorient_dots already exist, exiting"
    exit 1
fi

# check for the t2w-reorient flash-reorient warp
flash_warp_i=$(echo $flash_reorient | sed 's/acq-160um_echo-2_run-3_rec-reorient_FLASH/from-T2w_to-FLASH_warp_smooth/')
flash_warp=`ls ${flash_warp_i} 2> /dev/null`
if [[ ! -f $flash_warp ]] ; then
    echo "no file named ${flash_warp_i} ... making it (slow part)"
    flash_transform_prefix=$(echo $flash_warp_i | sed 's/from-T2w_to-FLASH_warp_smooth.nii.gz/from-T2w_to-FLASH_/')
    cmd="${scriptsdir}/t2wreorient_to_flashreorient.sh ${t2w_reorient} ${flash_reorient} ${flash_transform_prefix}"
    echo $cmd
    $cmd
else
    echo "${flash_warp} found"
    echo "" 
fi 

flash_affine_i=$(echo $flash_warp_i | sed 's/from-T2w_to-FLASH_warp_smooth.nii.gz/from-T2w_to-FLASH_affine.mat/')
flash_affine=`ls ${flash_affine_i} 2> /dev/null`

flash_warp=`ls ${flash_warp_i} 2> /dev/null`

if [[ -f $flash_warp ]] ; then 
    echo " found ${flash_warp} " 
    echo ""
else 
    echo " no warp ${flash_warp_i} , exiting"
    exit 1
fi

if [[ -f $flash_affine ]] ; then 
    echo " found affine ${flash_affine} " 
    echo ""
else 
    echo "no affine kind of like ${flash_affine_i} , exiting"
    exit 1
fi
# -ri LABEL 0.2vox \
dotstoflash="greedy -d 3 -threads 4 \
    -rf ${flash_reorient} \
    -ri NN \
    -rm ${t2w_reslice_dots} ${flash_reorient_dots} \
    -r  ${flash_warp} ${flash_affine} ${t2w_reslice_to_reorient},-1"
echo ${dotstoflash}
${dotstoflash}

