#!/bin/bash
bids_base=/project/ftdc_pipeline/pmc_exvivo/oriented/bids/
if [[ $# -lt 2 ]]; then 
    echo "USAGE: ./get_a_reorient_T2w_list.sh <list_of_inddids.txt/csv> <path/to/file/list.txt> " 
    echo " looks in $bids_base for INDDIDs in list and searches for rec-reorient_T2w.nii.gz"
fi

subjlist=$1
outfile=$2
basename_outfile=$(basename $outfile )
if [[ $outfile == $basename_outfile ]]; then 
    echo "save $outfile somewhere else...exiting"
    exit 1
fi

for i in `cat $subjlist `; do 
    sub=$(echo $i | cut -d ',' -f1)
    files=`ls ${bids_base}sub-INDD${sub}/ses-*/anat/sub-INDD${sub}_ses-*acq-300um_rec-reorient_T2w.nii.gz`
    esc_bids_base=$(echo $bids_base | sed 's/\//\\\//g')
    files2=$(echo $files | sed "s/${esc_bids_base}//g" )
    echo $files2 >> $outfile
done