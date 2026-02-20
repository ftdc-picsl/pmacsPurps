#!/bin/bash

bidsBase=/project/ftdc_pipeline/pmc_exvivo/oriented/bids/
purpleBase=/project/ftdc_pipeline/pmc_exvivo/oriented/purple_v1.4.2/exvivo_t2w/
qcBase=/project/ftdc_pipeline/pmc_exvivo/oriented/qc/

if [[ $# -lt 1 ]] ; then 
    echo "./submit_createPurpleQCpngs.sh <file_list> "
    echo " <file_list>  can be text file or csv with first column image file names relative to ${bidsBase}"
    exit 1
fi

filelist=$1
if [[ ! -d ${qcBase}/logs/ ]] ; then 
    mkdir -p ${qcBase}/logs/
fi
echo ${qcBase}/logs/ made 

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
    outdir=${purpleBase}${outdirpart}

    # pulkit's naming isn't bids but the software is cool so we roll with it
    infoutdir=${outdir}/data_for_inference/

    if [[ ! -d ${infoutdir} ]] ; then 
        mkdir -p ${infoutdir}
    fi
    
    purpsegname="${infoutdir}/output_from_nnunet_inference/${filestem}.nii.gz"
    purpseg=`ls ${purpsegname} 2> /dev/null`
    if [[ ! -f $purpseg ]] ; then
        echo "segmentation does not exist at ${purpsegname} ...skipping"
        continue
    else
        re0000rient=$(echo $filestem | sed 's/$/_0000.nii.gz/')

        echo "underlay ${f} ... "
        echo "overlay ${purpsegname} ... "

        cmd="createPurpleQCpngs.sh $f ${purpsegname} $bidsBase $qcBase"
        echo $cmd 
        bsub -n 1 -M 4GB -o ${qcBase}/logs//${filestem}_qc_pngs_%J.txt $cmd 
    fi
done