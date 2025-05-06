#!/bin/bash

outBase=/project/ftdc_pipeline/exvivo_7T/hemis/
bidsBase=/project/ftdc_volumetric/pmc_exvivo/bids/
purplemodel="exvivo_t2w"

outBase=${outBase}/${purplemodel}/
if [[ $# -lt 1 ]] ; then
	echo "./submit_purple_pipeline.sh <filelist.txt> "
    echo "  wrapper for 1) n4, 2) segmentation, and 3) cortex refinement of purple mri for ex vivo hemispheres "
    echo "  filelist.txt should be path to a raw bids nifti file in /anat/ , relative to $bidsin "
    echo "  output goes to $outBase "
	exit 1
fi

scriptsdir=`pwd`

segvrsn=v1.4.0
cruisevrsn=v1.0.0

filelist=$1
bindir=`pwd`

logdir=${outBase}logs/
if [[ ! -d $logdir ]] ; then 
    mkdir -p $logdir
fi
    

for i in `cat $filelist `; do 
    dirpart=$(dirname "$i")
    filepart=$(basename "$i")
    filestem=$(echo $filepart | sed 's/\.nii\.gz//' )
    anatcheck=$(echo $dirpart | grep "/anat$" )
    if [[ $anatcheck == "" ]] ; then 
        echo "data not in /anat/ so something's probably wrong ... exiting"
        exit 1
    fi
    
    outdirpart=$(echo $dirpart | sed 's/anat//')
    outdir=${outBase}${outdirpart}

    infoutdir=${outdir}/data_for_inference/
    if [[ ! -d ${infoutdir} ]] ; then 
        mkdir -p ${infoutdir}
    fi
    maskn4dir=${outdir}/mask_n4/
    if [[ ! -d $maskn4dir ]] ; then
        mkdir $maskn4dir
    fi

    n4out=`ls ${maskn4dir}/${filestem}_bias_corrected_norm_0000.nii.gz 2> /dev/null`
    if [[ -f $n4out ]] ; then
        echo "n4 output already exists..skipping that step"
        if [[ ! -f ${infoutdir}/${filestem}_bias_corrected_norm_0000.nii.gz ]] ; then 
            cp $n4out ${infoutdir}/
        fi
    else 


        cmd="${bindir}/mask_and_bias_correct.sh ${bidsBase}$i ${maskn4dir} ${filestem} " 
        echo $cmd 
        bsub -N -J ${filestem}_n4 -o ${logdir}/${filestem}_mask_and_n4_log_%J.txt -n 1 $cmd

        bwait -w "ended(${filestem}_n4)"

    fi

    n4out=`ls ${maskn4dir}/${filestem}_bias_corrected_norm_0000.nii.gz 2> /dev/null`
    if [[ ! -f $n4out ]] ; then
        echo "no n4 output named like i expected...exiting"
        echo ${maskn4dir}/${filestem}_bias_corrected_norm_0000.nii.gz
        exit 1
    else 
        cp ${n4out} ${infoutdir}
    fi


    purpsegname="${infoutdir}/output_from_nnunet_inference/${filestem}_bias_corrected_norm.nii.gz"
    purpseg=`ls ${purpsegname} 2> /dev/null`
    if [[ -f $purpseg ]] ; then
        echo "segmentation output already...skipping"
    else
        cmd="${bindir}/setupPurplemri.sh ${segvrsn} ${outdir} ${purplemodel} "
        echo $cmd 
        bsub -N -J ${filestem}_purple_${segvrsn} -gpu "num=1:mode=exclusive_process:mps=no:gtile=1" -o ${logdir}/${filestem}_purple_${segvrsn}_log_%J.txt -n 1 $cmd

        bwait -w "ended(${filestem}_purple_${segvrsn})"
    fi

    purpsegname="${infoutdir}/output_from_nnunet_inference/${filestem}_bias_corrected_norm.nii.gz"
    purpseg=`ls ${purpsegname} 2> /dev/null `
    if [[ ! -f $purpseg ]] ; then
        echo "no segmentation output named like i expected...exiting"
        echo " name should should be ${purpsegname} "
        exit 1
    fi

    topindir=${outdir}/data_for_topology_correction/

    cruiseout="${topindir}output_corrected_topology/${filestem}_bias_corrected_norm_gm_cortex_cruise_retained_overlap.nii.gz"
    if [[ -f $cruiseout ]] ; then
        echo "$cruiseout exists...all done...exiting " 
        exit 1
    else 
        if [[ ! -d ${topindir} ]] ; then
            mkdir -p ${topindir}
        fi

        cp ${purpsegname} ${topindir}

        cmd="${bindir}/cruise_control.sh -v ${cruisevrsn} -d ${outdir}"
        echo $cmd 
        bsub -N -J ${filestem}_purplecruise_${cruisevrsn} -o ${logdir}/${filestem}_purplecruise_${cruisevrsn}_log_%J.txt -n 1 $cmd
    fi
done
