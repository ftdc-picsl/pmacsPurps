#!/bin/bash

if [[ $# -lt 4 ]]; then
    echo "./t2wreorient_to_flashreorient.sh <t2w_reorient> <flash_reorient> <t2wreorient_in_flashreorient_filename> <scriptsdir>"

    exit 1
fi

module unload python
module unload greedy
module load greedy

t2w_reorient=$1
flash_reorient=$2
t2wreorient_in_flashreorient_filename=$3
scriptsdir=$4

t2wreorient_in_flashreorient_filename_check=`ls ${t2wreorient_in_flashreorient_filename} 2> /dev/null`
if [[ -f $t2wreorient_in_flashreorient_filename_check ]] ; then
    echo "$t2wreorient_in_flashreorient_filename already exist, exiting"
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
t2wtoflash="greedy -d 3 -threads 4 \
    -rf ${flash_reorient} \
    -ri NN \
    -rm ${t2w_reorient} ${t2wreorient_in_flashreorient_filename} \
    -r  ${flash_warp} ${flash_affine} "
echo ${t2wtoflash}
${t2wtoflash}

