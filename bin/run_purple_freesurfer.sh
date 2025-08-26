#!/bin/bash
# get things ready for freesurfer and submit

if [[ $# -lt 7 ]]; then
    echo "./run_purple_freesurfer.sh <filename> <hemi> <purple repo directory> <bids base directory> <segmentation t2 directory> <output base directory> <number threads>"
    echo " filename is the name sent into purple" 
    echo " hemi can be L (left) or R (right) "
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
n_threads=$7

if [[ $hemi != "L" && $hemi != "R" ]]; then 
    echo "ftdc error: hemi must be L (if left) or R (for right). It matters because everything gets flipped to right during this pipeline ... exiting"
    exit 1
fi

# everythign's based on the reorient T2 image. so see if what we think is there is there
reorient="${bidsBase}/${filename}"
reocheck=`ls ${reorient} 2> /dev/null`
if [[ -f $reocheck ]] ; then
    echo "reorient image found at ${reorient} "
else
    echo "ftdc error: reorient image not found at ${reorient} ... exiting "
    exit 1
fi
# chop up names for things
dirpart=$(dirname "$filename")
filepart=$(basename "$filename")
filestem=$(echo $filepart | sed 's/\.nii\.gz//' )

# create output directory name
outdirpart=$(echo $dirpart | sed 's/anat//')
outdir=${purpleProcBase}${outdirpart}

# pulkit's naming isn't bids but the software is cool so we roll with it
# setting that up here
# this script requires the purple segmentation of the hemisphere to have already been run. check for that here
infoutdir=${outdir}/data_for_inference/
purpsegname="${infoutdir}/output_from_nnunet_inference/${filestem}.nii.gz"
purpseg=`ls ${purpsegname} 2> /dev/null`
if [[ -f $purpseg ]] ; then
    echo "segmentation found at ${purpsegname} "
else
    echo "segmentation image not found at ${purpsegname} ... exiting "
    exit 1
fi

# this script uses scripts from a repo at https://github.com/Pulkit-Khandelwal/purple-mri
# look for and set up what we needs from it 
if [[ ! -d ${purplerepo} ]] ; then 
    echo "no directory for purple-mri repo at ${purplerepo} ... exiting"
    exit 1
else 
    surfacecheck=`ls ${purplerepo}/purple_mri/run_surface_pipeline.sh 2> /dev/null`
    if [[ ! -f ${surfacecheck} ]]; then 
        echo "no run_surface_pipeline.sh script found at ${purplerepo}/purple_mri/ ... exiting"
        exit 1
    fi
fi

# setting up output directory structure
freedir=$dirpart
freedir=$(echo $dirpart | cut -d '/' -f1-2 | sed 's/\//_/')
outDir=${outBase}/${freedir}/

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

if [[ $hemi == "L" ]]; then 
    rightreorient=${filestem}_right.nii.gz
    rightpurpleseg=${filestem}_right.nii.gz
    c3d ${reorient} -flip y ${reorientdir}/${rightreorient}
    c3d ${purpsegname} -flip y ${purplesegdir}/${rightpurpleseg}
else 
    cp ${reorient} ${reorientdir}
    cp ${purpsegname} ${purplesegdir}
fi

# load modules
# then set up rest of paths and dependencies 
module load python/3.9

module load freesurfer/7.4.0
source /appl/freesurfer-7.4.0/SetUpFreeSurfer.sh 
freepath="/appl/freesurfer-7.4.0/"

fstemplatedir=${purplerepo}/fsaverage/
if [[ ! -L ${outDir} ]] ; then 
    ln -s ${fstemplatedir} ${outDir}
fi

autodet=${purplerepo}/purple_mri/autodet.gw.stats.binary.rh.dat
if [[ ! -L ${outDir}/autodet.gw.stats.binary.rh.dat ]] ; then 
    ln -s ${autodet} ${outDir}
fi

fsatlases=${purplerepo}/freesurfer_atlases/

cd ${purplerepo}/purple_mri/

cmd="bash run_surface_pipeline.sh ${freepath} ${outDir} ${reorientdir} ${purplesegdir} ${fsatlases} ${n_threads}"
echo "beginning surface processing ...." 
echo $cmd
$cmd
