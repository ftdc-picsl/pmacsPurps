# read the mri files and create a list of the subjects
freesurfer_path=$1
working_dir=$2
mri_path=$3
segm_path=$4
external_atlases_path=$5
num_threads=$6
hemis=$7

subjects=()
for file in ${mri_path}/*.nii.gz
do
   fname=$(basename "$file" .nii.gz)
   subjects+=(${fname})
done

if [[ $hemis == "lh" ]] ; then
    hemiflag="--rh"
elif [[ $hemis == "rh" ]] ; then
    hemiflag="--lh"
else 
    echo "$hemis is wrong...exiting"
    exit 1
fi

for subj in "${subjects[@]}" ; do
    echo ${subj}
    SUBJECTS_DIR=${working_dir}/${subj}
    surfreg --s $subj --t fsaverage_sym $hemiflag --no-annot
    surfreg --s $subj --t fsaverage_sym $hemiflag --no-annot --xhemi
done
