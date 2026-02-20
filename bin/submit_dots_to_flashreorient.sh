#!/bin/bash

bidsBase=/project/ftdc_pipeline/pmc_exvivo/oriented/bids/
purplerepo=/project/ftdc_pipeline/purple_code/purple-mri_20250919/
scriptsdir=/project/ftdc_pipeline/ftdc-picsl/pmacsPurps-v0.2.1/bin/

if [[ $# -lt 1 ]] ; then
    echo "./submit_dots_to_flashreorient.sh <filelist,<<optional:hemi>>.csv> "
    echo "  wrapper for mapping the dots placed on t2w-reslice to the FLASH-reorient"
    echo "  filelist,hemi.csv should be path to a reoriented bids nifti file in /anat/ , relative to $bidsin, hemi is ignored (but allowed for to use same csv as for other stuff)"
    echo "  output goes to $outBase "
    exit 1
fi

filelist=$1
n_threads=1

outdir=${bidsBase}/derivatives/
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
    
    # check for the t2w-reslice image
    reslice_i=$(echo $i | sed 's/reorient/reslice/')
    reslice=`ls ${bidsBase}/${reslice_i} 2> /dev/null`
    if [[ ! -f $reslice ]] ; then
        echo "no file named ${bidsBase}/${reslice_i} ...skipping"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 
    echo "${reslice} found"
    echo "" 

    # check for the t2w-reslice to t2w-reorient mat 
    reslice_mat_i=$(echo $reslice_i | sed 's/\.nii\.gz/\.mat/')
    reslice_mat=`ls ${bidsBase}/${reslice_mat_i} 2> /dev/null`
    if [[ ! -f $reslice_mat ]] ; then
        echo "no file named ${bidsBase}/${reslice_mat_i} ...skipping"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 
    echo "${reslice_mat} found"
    echo "" 

    # check for the t2w-reslice dots image
    reslice_dots_i=$(echo $reslice_i | sed 's/acq-300um_rec-reslice_T2w/rec-reslice_space-T2w_cortexdots_final/')
    reslice_dots=`ls ${bidsBase}/${reslice_dots_i} 2> /dev/null`
    if [[ ! -f $reslice_dots ]] ; then
        echo "no file named ${bidsBase}/${reslice_dots_i} ...skipping"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 
    echo "${reslice_dots} found"
    echo "" 

    # check for the flash-reorient image
    flash_i=$(echo $reslice_i | sed 's/acq-300um_rec-reslice_T2w/acq-160um_echo-2_run-3_rec-reorient_FLASH/')
    flash=`ls ${bidsBase}/${flash_i} 2> /dev/null`
    if [[ ! -f $flash ]] ; then
        echo "no file named ${bidsBase}/${flash_i} ...skipping"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 
    echo "${flash} found"
    echo "" 

    # check for the flash-reorient dots image
    flash_dots_i=$(echo $reslice_i | sed 's/acq-300um_rec-reslice_T2w/rec-reorient_space-FLASH_cortexdots_final/')
    flash_dots=`ls ${bidsBase}/${flash_dots_i} 2> /dev/null`
    if [[ -f $flash_dots ]] ; then
        echo "file ${flash_dots} exists ...skipping"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 
    echo "$${bidsBase}/${flash_dots_i} not found ... proceeding"
    echo "" 


    cmd="${scriptsdir}/reslice_dots_to_flashreorient.sh ${reorient} ${reslice} ${reslice_mat} ${reslice_dots} ${flash} ${bidsBase}/${flash_dots_i} ${scriptsdir}"
    echo $cmd 
    # $cmd
    bsub -N -J ${filestem}_reslice_dots_to_flashreorient -o ${logdir}/${filestem}_reslice_dots_to_flashreorient_%J.txt -n 4 -M 64GB $cmd

done


