#!/bin/bash

if [[ $# -lt 4 ]]; then
    echo "./greedy_flash_to_t2w_organizer.sh <t2w_reorient> <flash_reorient> <outdir> <flash_in_t2w_filename> <scriptsdir>"

    exit 1
fi

module unload python
module unload greedy
module load greedy

t2w_reorient=$1
flash_reorient=$2
outdir=$3
flash_in_t2w_filename=$4
scriptsdir=$5

flashreorient_in_t2wreorient_filename_check=$(ls ${outdir}/${flash_in_t2w_filename} 2> /dev/null)
if [[ -f $flashreorient_in_t2wreorient_filename_check ]] ; then
    echo "$flashreorient_in_t2wreorient_filename_check already exists, exiting"
    exit 1
fi

# check for the t2w-reorient flash-reorient warp
filename=$(basename ${flash_in_t2w_filename})
bids_anat=$(dirname ${flash_in_t2w_filename})
fileroot=$(echo $filename | cut -d '_' -f1-2)

flash_warp_i="${outdir}/${bids_anat}/${fileroot}_from-FLASH_to-T2w_warp_smooth.nii.gz"

flash_warp=`ls ${flash_warp_i} 2> /dev/null`
if [[ ! -f $flash_warp ]] ; then
    echo "no file named ${flash_warp_i} ... making it (slow part)"
    flash_transform_prefix=$(echo $flash_warp_i | sed 's/from-FLASH_to-T2w_warp_smooth.nii.gz/from-FLASH_to-T2w_/')
    ss_bids_anat=$(dirname $flash_transform_prefix)
    if [[ ! -d $ss_bids_anat ]] ; then 
        mkdir -p $ss_bids_anat
    fi
    cmd="${scriptsdir}/greedy_flash_to_t2w.sh ${t2w_reorient} ${flash_reorient} ${flash_transform_prefix}"
    echo $cmd
    $cmd
else
    echo "${flash_warp} found"
    echo "" 
fi 

flash_affine_i=$(echo $flash_warp_i | sed 's/from-FLASH_to-T2w_warp_smooth.nii.gz/from-FLASH_to-T2w_affine.mat/')
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
flash_to_t2_cmd="greedy -d 3 -threads 4 \
    -rf ${t2w_reorient} \
    -ri NN \
    -rm ${flash_reorient} ${outdir}/${flash_in_t2w_filename} \
    -r  ${flash_warp} ${flash_affine} "
echo ${flash_to_t2_cmd}
${flash_to_t2_cmd}

