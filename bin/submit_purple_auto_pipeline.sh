#!/bin/bash

bidsBase=/project/ftdc_pipeline/pmc_exvivo/oriented/automated_reorient_ACPC/bids/
segvrsn=v1.4.2
purplemodel="exvivo_t2w"
outBase=/project/ftdc_pipeline/pmc_exvivo/oriented/purple_${segvrsn}/${purplemodel}/

if [[ $# -lt 1 ]] ; then
	echo "./submit_purple_pipeline.sh <filelist.txt> "
    echo "  wrapper for purple mri for ex vivo hemispheres "
    echo "  filelist.txt should be path to a reoriented bids nifti file in /anat/ , relative to $bidsBase "
    echo "  output goes to $outBase "
	exit 1
fi

scriptsdir=`pwd`

filelist=$1
bindir=`pwd`

logdir=${outBase}logs/
if [[ ! -d $logdir ]] ; then 
    mkdir -p $logdir
fi
    
for i in `cat $filelist `; do
    f=$(echo $i | cut -d ',' -f1)	
    # break apart input file name for usable parts
    dirpart=$(dirname "$f")
    filepart=$(basename "$f")
    filestem=$(echo $filepart | sed 's/\.nii\.gz//' )

    # check for the reorient image and then copy it to pulkit's expected directory and file naming convention
    reorient=`ls ${bidsBase}/${f} 2> /dev/null`
    if [[ ! -f $reorient ]] ; then
        echo "no file named ${reorient} ...exiting"
        # continue skips rest of loop for this line if no anat dir
        continue
    fi 
    echo "${reorient} found"
    echo "" 
    
    # create output directory name
    outdirpart=$(echo $dirpart | sed 's/anat//')
    outdir=${outBase}${outdirpart}

    # pulkit's naming isn't bids but the software is cool so we roll with it
    infoutdir=${outdir}/data_for_inference/

    if [[ ! -d ${infoutdir} ]] ; then 
        mkdir -p ${infoutdir}
    fi
    
    purpsegname="${infoutdir}/output_from_nnunet_inference/${filestem}_bias_corrected_norm.nii.gz"
    purpseg=`ls ${purpsegname} 2> /dev/null`
    if [[ -f $purpseg ]] ; then
        echo "segmentation output already at ${purpsegname} ...skipping"
        continue
    else
        re0000rient=$(echo $filestem | sed 's/$/_0000.nii.gz/')

        echo "going to purple this ${reorient} ... "
        echo " copying to ${infoutdir}/${re0000rient} to get going"

        cp ${reorient} ${infoutdir}/${re0000rient}
        chmod 774 ${infoutdir}/${re0000rient}
        
        cmd="${bindir}/setupPurplemri.sh ${bindir} ${segvrsn} ${outdir} ${purplemodel} "
        echo $cmd 
        bsub -N -J ${filestem}_purple_${segvrsn} -gpu "num=1:mode=exclusive_process:mps=no:gtile=1" -o ${logdir}/${filestem}_purple_${segvrsn}_log_%J.txt -n 1 $cmd
    fi

done
