#!/bin/bash

if [[ $# -lt 3 ]] ; then 
    echo "./mask_and_bias_correct.sh <infile> <out directory> <out root (no _)> "
    echo " creates a quick brain mask and then does N4 bias correction " 
    echo " based on pulkit's script, but i figure i may have to futz" 
    exit 1
fi


infile=$1
outdir=$2
outroot=$3

module unload ANTs
module unload c3d

module load ANTs/2.3.5
module load c3d/20191022

# pulkit's example parameters
# c3d ${infile} -thresh 1 inf 1 0 -dilate 1 2x2x2vox -holefill 1 -o ${outdir}/${outroot}_mask.nii.gz
# my guess
incheck=`ls $infile 2> /dev/null`
if [[ ! -f $incheck ]] ; then   
    echo " no $infile ...exiting " 
    exit 1
fi

cmd="c3d ${infile} -thresh 100 inf 1 0 -dilate 1 2x2x2vox -holefill 1 -o ${outdir}/${outroot}_mask.nii.gz"
echo $cmd
$cmd

cmd="c3d ${outdir}/${outroot}_mask.nii.gz -comp -threshold 1 1 1 0 -o ${outdir}/${outroot}_mask.nii.gz"
echo $cmd
$cmd

# must remove 0s 
c3d ${infile} -thresh 1 inf 0 1 ${outdir}/${outroot}_mask.nii.gz -times -o ${outdir}/${outroot}_mask.nii.gz"
echo $cmd
$cmd

# take largest component to get more or less just the brain part
cmd="c3d ${outdir}/${outroot}_mask.nii.gz -comp -threshold 1 1 1 0 -o ${outdir}/${outroot}_mask.nii.gz"
echo $cmd
$cmd

cmd="N4BiasFieldCorrection -d 3 \
            -i ${infile} \
            -x ${outdir}/${outroot}_mask.nii.gz -t 0.3 0.01 200 \
            -o ${outdir}/${outroot}_bias_corrected.nii.gz"
echo $cmd
$cmd

cmd="c3d ${outdir}/${outroot}_bias_corrected.nii.gz -stretch 0.1% 99.9% 0 1000 -clip 0 1000 -o ${outdir}/${outroot}_bias_corrected_norm_0000.nii.gz"
echo $cmd
$cmd

chgrp -R ftdclpc ${outdir}
chmod -R 774 ${outdir}
