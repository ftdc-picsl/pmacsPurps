#!/bin/bash

if [[ $# -lt 3 ]] ; then 
    echo "need 1) reorient bids image 2) purple seg 3) bids base dir 4) output base dir"
    exit 1
fi

reorient=$1
purpleseg=$2
bidsBase=$3
qcBase=$4
module load ANTs


dirpart=$(dirname "$reorient")
filepart=$(basename "$reorient" | sed 's/_T2w.nii.gz//')
outRoot=${qcBase}/${dirpart}/${filepart}

if [[ ! -d ${qcBase}/${dirpart}/ ]]; then 
    mkdir -p ${qcBase}/${dirpart}/
fi

purplemask="${outRoot}_desc-purplebrain_mask.nii.gz"
if [[ ! -f $purplemask ]] ; then 
    cmd="ThresholdImage 3 $purpleseg $purplemask 1 Inf 1 0 "
    $cmd
fi

purplesegrgb="${outRoot}_T2w_rgb.nii.gz"
if [[ ! -f $purplesegrgb ]] ; then 
    ConvertScalarImageToRGB 3 $purpleseg $purplesegrgb $purplemask jet 
fi 

png_ax="${outRoot}_desc-qcSegPURPLEAx.png"
if [[ ! -f $png_ax ]] ; then 
    CreateTiledMosaic -i ${bidsBase}/${reorient} -r $purplesegrgb -x $purplemask -a .3 -s 10 -f 1x1 -o $png_ax -d z
fi

png_cor="${outRoot}_desc-qcSegPURPLECor.png"
if [[ ! -f $png_cor ]] ; then 
    CreateTiledMosaic -i ${bidsBase}/${reorient} -r $purplesegrgb -x $purplemask -a .3 -s 10 -g 1 -f 0x1 -o $png_cor -d y
fi

png_ax="${outRoot}_desc-qcAx.png"
if [[ ! -f $png_ax ]] ; then 
    CreateTiledMosaic -i ${bidsBase}/${reorient} -r $purplesegrgb -a 0 -x $purplemask -s 10 -f 1x1 -o $png_ax -d z
fi

png_cor="${outRoot}_desc-qcCor.png"
if [[ ! -f $png_cor ]] ; then 
    CreateTiledMosaic -i ${bidsBase}/${reorient} -r $purplesegrgb -a 0 -x $purplemask -s 10 -g 1 -f 0x1 -o $png_cor -d y
fi

reslice_fpart=$(echo $reorient | sed 's/rec-reorient/rec-reslice/')
reslice_c=`ls ${bidsBase}/${reslice_fpart} 2> /dev/null `
reslice=""
if [[ -f $reslice_c ]] ; then 
    reslice=$reslice_c
    reslice_mat=$(echo $reslice | sed 's/.nii.gz/.mat/')
else 
    reslice_fpart=$(echo $reorient | sed 's/rec-reorient/rec-reslice_space-MNI/')
    reslice_c=`ls ${bidsBase}/${reslice_fpart} 2> /dev/null `
    if [[ -f $reslice_c ]] ; then 
        reslice=$reslice_c
        reslice_mat=$(echo $reslice | sed 's/rec-reslice_space-MNI_T2w.nii.gz/T2w_to_MNI_ACPC_space-MNI_0GenericAffine.mat/')
    fi 
fi
if [[ ! -f $reslice ]] ; then 
    echo "no reslice...exiting"
    exit 1
fi


reslice_filepart=$(basename $reslice | sed 's/_T2w.nii.gz//')
outResliceRoot=${qcBase}/${dirpart}/${reslice_filepart}

reslice_mask=${outResliceRoot}_dumbMask.nii.gz
ThresholdImage 3 $reslice $reslice_mask 1 Inf 0 1
outResliceRoot=${outResliceRoot}_dumblyMasked

png_ax="${outResliceRoot}_desc-qcAx.png"
if [[ ! -f $png_ax ]] ; then 
    CreateTiledMosaic -i $reslice -x $reslice_mask -r $reslice_mask -a 0 -s 10 -f 1x1 -o $png_ax -d z
fi

png_cor="${outResliceRoot}_desc-qcCor.png"
if [[ ! -f $png_cor ]] ; then 
    CreateTiledMosaic -i $reslice -x $reslice_mask -r $reslice_mask -a 0 -s 10 -g 1 -f 0x1 -o $png_cor -d y

fi