#!/bin/bash

bidsBase=/project/ftdc_pipeline/pmc_exvivo/oriented/bids/
purplerepo=/project/ftdc_pipeline/purple_code/purple-mri_20250919/
scriptsdir=/project/ftdc_pipeline/ftdc-picsl/pmacsPurps-v0.2.1/bin/
flashwarpdir=/project/ftdc_pipeline/pmc_exvivo/oriented/bids/derivatives/greedy_vBeta

if [[ $# -lt 1 ]] ; then
    echo "./t2wreorientimage_to_flashreorient.sh <filelist,<<optional:hemi>>.csv> "
    echo "  wrapper for moving the t2w-reorient image to the FLASH-reorient image for visually qc-ing the registration"
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
    
    # pick the FLASH 
    # second echo of the third run for the OG, and channel COMB, second echo of the second run positive direction for the a_gre
    reroot=$(echo $i | sed 's/acq-300um_rec-reorient_T2w.nii.gz//')

    for flash_pick in 'acq-160um_echo-2_run-3_rec-reorient_FLASH.nii.gz' 'acq-160um_echo-2_run-2_rec-reorient_FLASH.nii.gz' 'acq-160um_echo-2_rec-reorient_FLASH.nii.gz' \
        'acq-channelCOMBx160um_dir-positive_run-02_echo-2_part-mag_rec-reorient_FLASH.nii.gz' 'acq-channelCOMBx160um_dir-positive_echo-2_part-mag_rec-reorient_FLASH.nii.gz' ; do 
        # echo $flash_pick
        # check for the flash-reorient image
        flash_i=$(echo $i | sed "s/acq-300um_rec-reorient_T2w.nii.gz/${flash_pick}/")
        flash=`ls ${bidsBase}/${flash_i} 2> /dev/null`
        if [[ -f $flash ]] ; then
            echo "${flash} found"
            break
        fi
    done 
    
    if [[ ! -f $flash ]] ; then
        echo "no flash found in ${bidsBase}/${dirpart} ...skipping"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 
    echo "" 

    # check for the flash-reorient dots image
    t2w_in_flash_i=$(echo $i | sed 's/acq-300um_rec-reorient_T2w/acq-300um_rec-reorient_space-FLASH_T2w/')
    t2w_in_flash=`ls ${bidsBase}/${flash_dots_i} 2> /dev/null`
    if [[ -f $t2w_in_flash ]] ; then
        echo "file ${t2w_in_flash} exists ...skipping"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 
    echo "${bidsBase}/${t2w_in_flash_i} not found ... proceeding"
    echo "" 


    # cmd="${scriptsdir}/t2wreorientimage_to_flashreorient.sh ${reorient} ${flash} ${bidsBase}/${t2w_in_flash_i} ${scriptsdir}"
    # echo $cmd 
    # $cmd
    # bsub -N -J ${filestem}_t2wreorientimage_to_flashreorient -o ${logdir}/${filestem}_t2wreorientimage_to_flashreorient_%J.txt -n 4 -M 32GB $cmd

done


