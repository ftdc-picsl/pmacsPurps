#!/bin/bash

bidsBase=/project/ftdc_pipeline/pmc_exvivo/oriented/bids/
segvrsn=v1.4.2
outBase=/project/ftdc_pipeline/data/purple_${segvrsn}/${purplemodel}/
purplemodel="exvivo_t2w"
purplerepo=/project/ftdc_pipeline/purple_code/purple-mri_20250513/

if [[ $# -lt 1 ]] ; then
    echo "./submit_purple_freesurfer.sh <filelist,hemi.csv> "
    echo "  wrapper for running freesurfer on ex vivo hemisphere following purple mri "
    echo "  filelist,hemi.csv should be path to a reoriented bids nifti file in /anat/ , relative to $bidsin, followed by L or R for which hemisphere was imaged"
    echo "  output goes to $outBase "
    exit 1
fi

scriptsdir=`pwd`

filelist=$1
bindir=`pwd`
n_threads=1

freeoutdir=${outBase}/freesurfer_out/
logdir=${freeoutdir}logs/
if [[ ! -d $logdir ]] ; then 
    mkdir -p $logdir
fi
    
for x in `cat $filelist `; do 
    # break apart input file name for usable parts
    i=$(echo $x | cut -d ',' -f1)
    dirpart=$(dirname "$i")
    filepart=$(basename "$i")
    filestem=$(echo $filepart | sed 's/\.nii\.gz//' )

    hemi=$(echo $x | cut -d ',' -f2 )
    if [[ $hemi != "L" && $hemi != "R" ]]; then
        echo " hemisphere must be L or R and you put: ${hemi} ...skipping"
        continue
    fi

    # check for the reorient image and then copy it to pulkit's expected directory and file naming convention
    reorient=`ls ${bidsBase}/${i} 2> /dev/null`
    if [[ ! -f $reorient ]] ; then
        echo "no file named ${bidsBase}/${i} ...skipping"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 
    echo "${reorient} found"
    echo "" 
    
    # create purple seg output directory name
    outdirpart=$(echo $dirpart | sed 's/anat//')
    outdir=${outBase}${outdirpart}
    # pulkit's naming isn't bids but the software is cool so we roll with it
    infoutdir=${outdir}/data_for_inference/


    purpsegname="${infoutdir}/output_from_nnunet_inference/${filestem}.nii.gz"
    purpseg=`ls ${purpsegname} 2> /dev/null`
    if [[ ! -f $purpseg ]] ; then
        echo "no segmentation output ${purpsegname} ...skipping"
        continue
    else

        cmd="${bindir}/run_purple_freesurfer.sh ${i} ${hemi} ${purplerepo} ${bidsBase} ${outBase} ${freeoutdir} ${n_threads} "
        echo $cmd 
        bsub -N -J ${filestem}_purplefree -o ${logdir}/${filestem}_purplefree_log_%J.txt -n 1 $cmd
    fi

done
