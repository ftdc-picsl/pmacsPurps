#!/bin/bash

if [[ $# -lt 3 ]]; then
    echo "USAGE: ./t2wreorient_to_flashreorient.sh <t2w_reorient> <flash_reorient> <flash_transform_prefix> "
    exit 1
fi

module unload greedy
module load greedy

t2w_reorient=$1
flash_reorient=$2
flash_transform_prefix=$3

# greedy inputs are specified as t2w-reorient the moving and flash-reorient fixed, so trensforms all named from-T2w_to-FLASH

# greedy -d 3 -threads 4 \
#    -i ${t2w_reorient} ${flash_reorient} \
#    -m WNCC 2x2x2 -moments \
#    -o ${flash_transform_prefix}moments.mat

#greedy -d 3 -threads 4 -a -dof 12 \
#    -i ${t2w_reorient} ${flash_reorient} \
#    -n 50x25x0 -m WNCC 2x2x2 -ia ${flash_transform_prefix}moments.mat \
#    -o ${flash_transform_prefix}affine.mat

greedy -d 3 -threads 4 -a -dof 12 \
    -i ${flash_reorient} ${t2w_reorient} \
    -n 50x25x0 -m WNCC 2x2x2 -ia-image-centers \
    -o ${flash_transform_prefix}affine.mat

greedy -d 3 -threads 4 \
    -i ${flash_reorient} ${t2w_reorient} \
    -it ${flash_transform_prefix}affine.mat -n 50x25x0 -m WNCC 2x2x2 -s 8.0mm 1.0mm -sv \
    -o ${flash_transform_prefix}warp_smooth.nii.gz \
    -oinv ${flash_transform_prefix}inverse_warp_smooth.nii.gz

