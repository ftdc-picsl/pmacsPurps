#!/bin/bash
# get things ready for freesurfer and submit

if [[ $# -lt 7 ]]; then
    echo "./ <filename> <hemi> <purple repo directory> <bids base directory> <segmentation t2 directory> <output base directory> <number threads>"
    echo " filename is the name sent into purple" 
    echo " hemi can be l (left) or r (right) "
    echo "      we dummy left hemispheres to right by reflecting across y-axis" 
    echo " purple repo directory contains the purple freesurfer submit script"
    echo " bids base directory contains the reorient T2 image"
    echo " segmentation t2 directory contains the output of purple segmentation"
    echo " output base directory will get idxsession directory for output of freesurfer "
    echo " number of threads for parcellation" 
    exit 1
fi

module load c3d/20191022

filename=$1
hemi=$2
purplerepo=$3
bidsBase=$4
purpleProcBase=$5
outBase=$6


if [[ $hemi != "l" & $hemi != "r" ]]; then 
    echo "hemi must be l (if left) or r (for right) ... exiting"
    exit 1
fi

reorient="${bidsBase}/${filename}"
reocheck=`ls ${reorient} 2> /dev/null`
if [[ -f $reocheck ]] ; then
    echo "reorient image found at ${reorient} "
else
    echo "reorient image not found at ${reorient} ... exiting "
    exit 1
fi

dirpart=$(dirname "$filename")
filepart=$(basename "$filename")
filestem=$(echo $filepart | sed 's/\.nii\.gz//' )
# create output directory name
outdirpart=$(echo $dirpart | sed 's/anat//')
outdir=${outBase}${outdirpart}
# pulkit's naming isn't bids but the software is cool so we roll with it
infoutdir=${outdir}/data_for_inference/
purpsegname="${infoutdir}/output_from_nnunet_inference/${filestem}_bias_corrected_norm.nii.gz"
purpseg=`ls ${purpsegname} 2> /dev/null`
if [[ -f $purpseg ]] ; then
    echo "segmentation found at ${purpsegname} "
else
    echo "segmentation image not found at ${purpsegname} ... exiting "
    exit 1
fi


if [[ ! -d ${purplerepo} ]] ; then 
    echo "no directory for purple post scripts at ${purplerepo} ... exiting"
    exit 1
else 
    cd ${purplerepo}
    surfacecheck=`ls run_surface_pipeline.sh 2> /dev/null`
    if [[ ! -f ${surfacecheck} ]]; then 
        echo "no run_surface_pipeline.sh script found at `pwd` ... exiting"
        exit 1
    fi
fi


freedir=$(echo $dirpart | cut -d '/' -f1-2 | sed 's/\//xx/')
outDir=${outBase}/${freedir}
if [[ ! -d ${outDir} ]]; then 
    mkdir -p ${outDir}
fi
reorientdir=${outDir}/reorient
if [[ ! -d ${reorientdir} ]]; then 
    mkdir ${reorientdir}
fi
purplesegdir=${outDir}/purpleseg
if [[ ! -d ${purplesegdir} ]]; then 
    mkdir ${purplesegdir}
fi

if [[ $hemi == "l" || $hemi =="L"]]; then 
    rightreorient=${filestem}_right.nii.gz
    rightpurpleseg=${filestem}_right_bias_corrected_norm.nii.gz
    c3d ${reorient} -flip y ${reorientdir}/${rightreorient}
    c3d ${purpsegname} -flip y ${purplesegdir}/${rightpurpleseg}
else 
    cp ${reorient} ${reorientdir}
    cp ${purpsegname} ${purplesegdir}
fi

module load freesurfer/7.4.0
freepath=`which recon_all | sed 's/recon_all//'`
cmd="bash run_surface_pipeline.sh ${freepath} ${outDir} ${reorient} ${purpsegname} na ${n_threads}"
echo "beginning surface processing ...." 
echo $cmd
$cmd
