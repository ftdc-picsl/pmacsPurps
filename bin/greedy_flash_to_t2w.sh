#!/bin/bash

if [[ $# -lt 3 ]]; then
    echo "USAGE: ./greedy_flash_to_t2w.sh <t2w_reorient> <flash_reorient> <flash_to_t2w_transform_prefix> "
    exit 1
fi

module unload greedy
module load greedy

t2w_reorient=$1
flash_reorient=$2
flash_to_t2w_transform_prefix=$3

# greedy usage: -i fixed moving

greedy -d 3 -threads 4 -a -dof 12 \
    -i ${t2w_reorient} ${flash_reorient} \
    -n 250x100x50x25x0 -m WNCC 2x2x2 -ia-image-centers \
    -o ${flash_to_t2w_transform_prefix}_affine.mat

greedy -d 3 -threads 4 \
    -i ${t2w_reorient} ${flash_reorient} \
    -it ${flash_to_t2w_transform_prefix}_affine.mat -n 50x25x0 -m WNCC 2x2x2 \
    -s 8.0mm 1.0mm -sv -wp 0 \
    -oroot ${flash_to_t2w_transform_prefix}_root_warp.nii.gz 

echo "${flash_to_t2w_transform_prefix}_root_warp.nii.gz ${flash_to_t2w_transform_prefix}_affine.mat" \
    > ${flash_to_t2w_transform_prefix}.txt

echo "${flash_to_t2w_transform_prefix}_affine.mat,-1 ${flash_to_t2w_transform_prefix}_root_warp.nii.gz,-1" \
    > ${flash_to_t2w_transform_prefix}_inverted_from-T2w_to-FLASH.txt
