#!/bin/bash

bidsBase=/project/ftdc_pipeline/pmc_exvivo/oriented/bids/
purplerepo=/project/ftdc_pipeline/purple_code/purple-mri_20250919/
scriptsdir=/project/ftdc_pipeline/ftdc-picsl/pmacsPurps-v0.3.0/bin/
outdir=${bidsBase}/derivatives/greedy_flash_to_t2/
logdir=${outdir}logs/

if [[ $# -lt 1 ]] ; then
    echo "./submit_greedy_flash_to_t2w_organizer.sh <filelist,<<optional:hemi>>.csv> "
    echo "  wrapper for moving the FLASH-reorient image to t2w-reorient"
    echo "  filelist{,optional:hemi}.csv should be path to a reoriented bids nifti file in /anat/ , relative to $bidsin, hemi is ignored (but allowed for to use same csv as for other stuff)"
    echo "  output goes to $outdir "
    exit 1
fi

filelist=$1
n_threads=1

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
    t2w_reorient=`ls ${bidsBase}/${i} 2> /dev/null`
    if [[ ! -f $t2w_reorient ]] ; then
        echo "no file named ${bidsBase}/${i} ...skipping"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 
    echo "${t2w_reorient} found"
    echo "" 
    
    # pick the FLASH 
    # second echo of the third run for the OG, and for a_gre the channel COMB second echo of the second run positive direction
    for flash_pick in 'acq-160um_echo-2_run-3_rec-reorient_FLASH.nii.gz' 'acq-160um_echo-2_run-2_rec-reorient_FLASH.nii.gz' 'acq-160um_echo-2_rec-reorient_FLASH.nii.gz' \
        'acq-channelCOMBx160um_dir-positive_run-02_echo-2_part-mag_rec-reorient_FLASH.nii.gz' 'acq-channelCOMBx160um_dir-positive_echo-2_part-mag_rec-reorient_FLASH.nii.gz' ; do 
        # echo $flash_pick
        # check for the flash-reorient image
        flash_reorient_i=$(echo $i | sed "s/acq-300um_rec-reorient_T2w.nii.gz/${flash_pick}/")
        flash_reorient=`ls ${bidsBase}/${flash_reorient_i} 2> /dev/null`
        if [[ -f $flash_reorient ]] ; then
            echo "${flash_reorient} found"
            break
        fi
    done 
    
    if [[ ! -f $flash_reorient ]] ; then
        echo "no flash found in ${bidsBase}/${dirpart} ...skipping"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 
    echo "" 

    filename=$(basename ${flash_reorient_i})
    bids_anat=$(dirname ${flash_reorient_i})
    flash_in_t2w_filename=$(echo $filename | sed 's/rec-reorient_FLASH/rec-reorient_space-T2w_FLASH/')

    flash_in_t2w_i="${bids_anat}/${flash_in_t2w_filename}"
    flash_in_t2w=`ls ${outdir}/${flash_in_t2w_i} 2> /dev/null`
    if [[ -f $flash_in_t2w ]] ; then
        echo "file ${flash_in_t2w} exists ...skipping"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 
    echo "${outdir}/${flash_in_t2w_i} not found ... proceeding"
    echo "" 


    cmd="${scriptsdir}/greedy_flash_to_t2w_organizer.sh ${t2w_reorient} ${flash_reorient} ${outdir} ${flash_in_t2w_i} ${scriptsdir}"
    echo $cmd 
    # $cmd
    bsub -N -J ${filestem}_greedy_flash_to_t2w -o ${logdir}/${filestem}_greedy_flash_to_t2w_%J.txt -n 4 -M 32GB $cmd

done


