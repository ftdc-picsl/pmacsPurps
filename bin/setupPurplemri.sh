#!/bin/sh

if [[ $# -lt 4 ]] ; then 
	echo "./setupPurplemri.sh <bindir> <version> <i/o base, eg working directory> <purple-mri model> "
	echo " working directory should be the sub-SUBID/ses-SESID/ directory that contains a data_for_inference directory that contains a reorient_t2_0000.nii.gz" 
	echo " this wrapper passes the purple-mri model into the required option " 
	echo " options are exvivo_t2w: Model trained on t2w mri to get the 10 labels. "
	echo " 			exvivo_flash_more_subcort: Added four new segmentation labels: hypothal, optic chiasm, anterior commissure, fornix. This model has been trained on the flash t2star mri."
	echo " 			exvivo_ciss_t2w: Multi-input segmentation to solve the anterior/posterior missing segmentation issue." 
	echo " 			invivo_flair_wmh: White matter hyperintensities segmentation on invivio flair" 
	exit 1
fi
bindir=$1
version=$2
workdir=$3
purplemodel=$4
# Record job ID.
echo "LSB job ID: ${LSB_JOBID}"
start_time=$(date +"%Y-%m-%d %H:%M:%S")
echo "Started at: ${start_time}"

module load singularity/3.8.3

${bindir}/runPurplemri.sh \
   	-v ${version} \
	-o ${workdir} \
	-i ${workdir} \
	-c 1 \
	-- \
	--"${purplemodel}"

end_time=$(date +"%Y-%m-%d %H:%M:%S")
echo "Ended at: ${end_time}"

chgrp -R ftdclpc ${workdir}
chmod -R 774 ${workdir}
