#!/bin/bash

bidsBase=/project/ftdc_pipeline/pmc_exvivo/oriented/bids/
purplerepo=/project/ftdc_pipeline/purple_code/purple-mri_20250919/
scriptsdir=/project/ftdc_pipeline/ftdc-picsl/pmacsPurps-v0.2.1/bin/
outdir=${bidsBase}/derivatives/beta_FLASH_T2w/

if [[ $# -lt 1 ]] ; then
    echo "./submit_dots_flash_summaries.sh <filelist,<<optional:hemi>>.csv> "
    echo "  wrapper for using c3d to summarize the dots to FLASH-reorient instensities"
    echo "  filelist,hemi.csv should be path to a reoriented bids nifti file in /anat/ , relative to $bidsin, hemi is ignored (but allowed for to use same csv as for other stuff)"
    echo "  output goes to $outBase "
    exit 1
fi

filelist=$1
n_threads=1

logdir=${outdir}logs/
if [[ ! -d $logdir ]] ; then 
    mkdir -p $logdir
fi
    
for x in `cat $filelist `; do 
    # break apart input file name for usable parts
    i=$(echo $x | cut -d ',' -f1)
    dirpart=$(dirname "$i")
    filepart=$(basename "$i")
    filestem=$(echo $filepart | sed 's/\.nii\.gz//' )
   
    # check for the t2w-reorient image 
    reorient=`ls ${bidsBase}/${i} 2> /dev/null`
    if [[ ! -f $reorient ]] ; then
        echo "no file named ${bidsBase}/${i} ...skipping"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 
    echo "${reorient} found"
    echo "" 
    
    # check for manually resliced t2w-reslice image
    reslice_bidschunk="reslice"
    reslice_i=$(echo $i | sed "s/reorient/$reslice_bidschunk/")
    reslice=`ls ${bidsBase}/${reslice_i} 2> /dev/null`
    # if no manually resliced, we check for automatic
    if [[ ! -f $reslice ]] ; then
        reslice_bidschunk="reslice_space-MNI"
    fi 
    reslice_i=$(echo $i | sed "s/reorient/$reslice_bidschunk/")
    reslice=`ls ${bidsBase}/${reslice_i} 2> /dev/null`
    if [[ ! -f $reslice ]] ; then
        echo "no T2w reslice in manual or auatomatic file naming in  ${bidsBase}/${dirpart} ...skipping"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 

    # check for the flash-reorient image
    flash_i=$(echo $reslice_i | sed "s/acq-300um_rec-${reslice_bidschunk}_T2w/acq-160um_echo-2_run-3_rec-reorient_FLASH/")
    flash=`ls ${bidsBase}/${flash_i} 2> /dev/null`
    if [[ ! -f $flash ]] ; then
        echo "no file named ${bidsBase}/${flash_i} ...skipping"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 
    echo "${flash} found"
    echo "" 

    # check for the flash-reorient dots image
    flash_dots_i=$(echo $reslice_i | sed "s/acq-300um_rec-${reslice_bidschunk}_T2w/rec-reorient_space-FLASH_cortexdots_final/")
    flash_dots=`ls ${outdir}/${flash_dots_i} 2> /dev/null`
    if [[ ! -f $flash_dots ]] ; then
        echo "no file ${outdir}/${flash_dots_i} exists ...skipping"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 
    
    echo "" 


    cmd="${scriptsdir}/dots_flash_summary.sh ${flash} ${outdir}/${flash_dots_i} ${scriptsdir}"
    echo $cmd 
    # $cmd
    bsub -N -J ${filestem}_reslice_dots_to_flashreorient -o ${logdir}/${filestem}_reslice_dots_to_flashreorient_%J.txt -n 1 -M 12GB $cmd

done


