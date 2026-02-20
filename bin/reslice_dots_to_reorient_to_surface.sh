#!/bin/bash

if [[ $# -lt 5 ]]; then
    echo "./ <filename> <hemi> <purple repo directory> <bids base directory> <output base directory> "
    echo " filename is the name sent into purple" 
    echo " hemi can be L (left) or R (right) "
    echo "      we dummy left hemispheres to right by reflecting across y-axis" 
    echo " purple repo directory contains the purple freesurfer submit script"
    echo " bids base directory contains the dots, reslice, and reorient T2 image"
    echo " segmentation t2 directory contains the output of purple segmentation"
    echo " output base directory will get idxsession directory for output of freesurfer "
    echo " number of threads for parcellation" 
    exit 1
fi

module unload freesurfer
module load freesurfer/7.4.0

module unload python

module unload c3d
module load c3d/20250523

module load greedy

t2reorient=$1
hemi=$2
purplerepo=$3
bidsBase=$4
outBase=$5

dotsscriptsdir=${purplerepo}/misc_scripts/dots_to_template/

if [[ $hemi != "L" && $hemi != "R" ]]; then 
    echo "ftdc error: hemi must be L (if left) or R (for right). It matters because everything gets flipped to right during this pipeline ... exiting"
    exit 1
fi

# chop up names for things
dirpart=$(dirname "$t2reorient")
dirpart=${bidsBase}/${dirpart}/
t2reorient_filename=$(basename "$t2reorient")
t2reorient_filestem=$(echo $t2reorient_filename | sed 's/\.nii\.gz//' )
# subj=sub-${sub}_ses-${ses}
subj=$(echo $t2reorient_filestem | cut -d '_' -f1-2)


freeoutdir=${outBase}/freesurfer_out/

workdir=${freeoutdir}work/
if [[ ! -d $workdir ]] ; then 
    mkdir -p $workdir
fi

dotsoutdir=${freeoutdir}${subj}/dots/
if [[ ! -d $dotsoutdir ]] ; then 
    mkdir -p $dotsoutdir
fi

reslice_mat_filename=$(echo $t2reorient_filename | sed 's/reorient/reslice/' | sed 's/nii\.gz/mat/' )
reslice_mat=`ls ${dirpart}/${reslice_mat_filename} 2> /dev/null`
if [[ ! -f $reslice_mat ]] ; then
    echo "no ${reslice_mat_filename} in ${dirpart} .... exiting"
    exit 1
else
    echo " found ${reslice_mat}" 
    echo ""
fi

subses=$(echo $t2reorient_filestem | cut -d '_' -f1-2)
reslice_dots=`ls ${dirpart}/${subses}_rec-reslice_space-T2w_cortexdots_final.nii.gz 2> /dev/null`
if [[ ! -f $reslice_dots ]] ; then
    echo "no ${reslice_dots} .... exiting"
    exit 1
else
    echo " found ${reslice_dots}" 
    echo ""
fi

reorient_dots_filename=`basename ${reslice_dots} | sed 's/reslice/reorient/' `
reorient_dots=`ls ${dirpart}/${reorient_dots_filename} 2> /dev/null`

if [[ -f $reorient_dots ]] ; then 
    echo " found ${reorient_dots} " 
    echo ""
else 
    invdots="greedy -d 3 -rf ${reorient_t2} -ri LABEL 0.2vox -rm ${reslice_dots} ${reorient_dots} -r ${reslice_mat},-1"
    echo ${invdots}
    ${invdots}
fi

# dots need to be in right hemisphere 
reorientdir=${freeoutdir}${subj}/reorient
if [[ $hemi == "L" ]]; then 
    dotsrightreorient=${subses}_rec-reorient_space-T2w_cortexdots_final_right.nii.gz
    if [[ ! -f ${reorientdir}/{dotsrightreorient} ]] ; then 
        c3d ${reorient_dots} -flip y ${reorientdir}/${dotsrightreorient}
    fi
else 
    cp ${reorient_dots} ${reorientdir}
fi

dscmd="./dots_to_surface_template_co.sh ${freeoutdir}${subj} ${workdir} ${reorientdir} ${dotsoutdir} ${purplerepo} ${subj} " 
echo $dscmd
$dscmd