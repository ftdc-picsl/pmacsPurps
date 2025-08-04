#!/bin/bash

if [[ $# -lt 6 ]] ; then 
  echo "USAGE ./dots_to_surface_template_co.sh <freesurfer_out_directory> <working_dir> <cortexfinal_dots_dir> <output_dir> <purple_repo_dir> <sub_ses>"
  echo  " freesurfer_out_directory: /path/to/freesurfer/processed/files/per_subject " 
  echo  " working_dir: /path/to/working_dir. temporary, maybe clean up on exit eventually"
  echo  " dots_base_dir: /path/to/cortexdots_final_dir " 
  echo  " output_dir: /path/to/processed_files_dir " 
  echo  " purple_repo_dir: /path/to/purple repo. used for finding surface vtk and other scripts" 
  echo  " sub_ses: to process"
  echo  " REQUIREMENTS: "
  echo  "   c3d "
  echo  "   freesurfer "
  echo  "   python3 "
  echo  "   greedy "
  exit 1
fi


SUBJECTS_DIR=$1
# Place the fsaverage folder in the fsaverage_files folder (to avoid any errors)
fsaverage_files=${SUBJECTS_DIR}/fsaverage
working_dir=$2
dot_dir=$3
processed_files=$4
purple_repo_dir=$5
subj=$6

scripts_dir=${purple_repo_dir}/misc_scripts/dots_to_template/
mesh_bin_dir=${purple_repo_dir}/glm/binaries
fsaverage_pial_surface=${scripts_dir}/fsaverage_pial.vtk


hemis=rh
hemis_other=lh
export SUBJECTS_DIR=$SUBJECTS_DIR
echo "Processing: " ${subj}
# make a folder for each subject
mkdir -p ${working_dir}/${subj}

# copy the ${subj}_cortexdots_final.nii.gz to the working directory
cp ${dot_dir}/${subj}_rec-reorient_space-T2w_cortexdots_final*.nii.gz ${working_dir}/${subj}/${subj}_cortexdots_final.nii.gz

# split all the dot labels into different files in their corresponding subject folder
# c3d ${working_dir}/${subj}/${subj}_cortexdots_final.nii.gz -split -oo ${working_dir}/${subj}/${subj}_cortexdots_final_label%02d.nii.gz

# use the Python version
python3 ${scripts_dir}/split_labels.py ${working_dir}/${subj}/ ${subj}
raw_list=$(cat ${working_dir}/${subj}/"unique_labels_${subj}.txt")
clean_list=$(echo "$raw_list" | tr -d '[],')
read -a valid_labels <<< "$clean_list"
cp ${working_dir}/${subj}/unique_labels_${subj}.txt ${processed_files}

# inflate each individual dot
bash ${scripts_dir}/dilation_split_dots.sh ${working_dir} ${subj}

subj_dots_file=${subj}_cortexdots_final
for num in "${valid_labels[@]}"
do
  echo ${subj} "label:" ${num}

  # convert to mgz file
  mri_convert ${working_dir}/${subj}/${subj_dots_file}_label${num}_dilated.nii.gz ${working_dir}/${subj}/${subj_dots_file}_label${num}.mgz

  # project the inflated dots to the native space surface
  mri_vol2surf --src ${working_dir}/${subj}/${subj_dots_file}_label${num}.mgz --out ${working_dir}/${subj}/${subj_dots_file}_label${num}.mgh --regheader ${subj} --hemi ${hemis} --projfrac-max 0 1 .1

  # project the native mgh file to the fsaverage space
  mris_preproc --s ${subj} --target fsaverage --hemi ${hemis} --is ${working_dir}/${subj}/${subj_dots_file}_label${num}.mgh --out ${working_dir}/${subj}/${subj_dots_file}_label${num}.fsaverage.mgh

  # convert mgh to vtk (on inflated and pial) in native space
  mris_convert -c ${working_dir}/${subj}/${subj_dots_file}_label${num}.mgh ${SUBJECTS_DIR}/${subj}/surf/${hemis}.inflated ${working_dir}/${subj}/${subj_dots_file}_label${num}.inflated.vtk

  mris_convert -c ${working_dir}/${subj}/${subj_dots_file}_label${num}.mgh ${SUBJECTS_DIR}/${subj}/surf/${hemis}.pial ${working_dir}/${subj}/${subj_dots_file}_label${num}.pial.vtk

  # convert mgh to vtk (on inflated and pial) in fsaverage space
  mris_convert -c ${working_dir}/${subj}/${subj_dots_file}_label${num}.fsaverage.mgh ${fsaverage_files}/surf/${hemis}.inflated ${working_dir}/${subj}/${subj_dots_file}_label${num}.fsaverage.inflated.vtk

  mris_convert -c ${working_dir}/${subj}/${subj_dots_file}_label${num}.fsaverage.mgh ${fsaverage_files}/surf/${hemis}.pial ${working_dir}/${subj}/${subj_dots_file}_label${num}.fsaverage.pial.vtk
done

python3 ${scripts_dir}/prepare_vtk_file_for_merge.py ${working_dir} ${subj}

####### merge arrays
c3d ${working_dir}/${subj}/${subj}_cortexdots_final.nii.gz -dup -lstat >> ${processed_files}/${subj}_dots_info.txt

# We will add a dummy first vtk mesh as just the pial surface
# so that we can load the mesh onto Paraview and start looking at 1 to 19 dots
# and ignore the index 0

# Get from here: https://github.com/Pulkit-Khandelwal/purple-mri/blob/main/misc_scripts/dots_to_template/fsaverage_pial.vtk
cp ${fsaverage_pial_surface} ${working_dir}/${subj}/${hemis}.${subj}_cortexdots_final_label0.fsaverage.pial_use.vtk
for num in $(seq 0 19)
do
  if [ -f "${working_dir}/${subj}/${hemis}.${subj}_cortexdots_final_label${num}.fsaverage.pial_use.vtk" ]; then
    echo "Dot ${num} was placed!"
   else
    echo "Dot ${num} was NOT placed!"
    cp ${fsaverage_pial_surface} ${working_dir}/${subj}/${hemis}.${subj}_cortexdots_final_label${num}.fsaverage.pial_use.vtk
  fi
    echo ${working_dir}/${subj}/${hemis}.${subj}_cortexdots_final_label${num}.fsaverage.pial_use.vtk \ >> ${working_dir}/${subj}/"merge_arrays_string_${subj}.txt"
done

${mesh_bin_dir}/mesh_merge_arrays -B -c \
${working_dir}/${subj}/${subj}_all_dots_fsaverage.${surface}.vtk dots $(cat ${working_dir}/${subj}/"merge_arrays_string_${subj}.txt")

cp ${working_dir}/${subj}/${subj}_all_dots_fsaverage.${surface}.vtk ${processed_files}
