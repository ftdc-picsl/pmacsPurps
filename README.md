# pmacsPurps
Wrappers for submitting purple-mri jobs on the PMACS LPC

We have containers of Pulkit's 7T segmentation software, purple-mri ([https://github.com/Pulkit-Khandelwal/purple-mri ]()), on the PMACS LPC. When accessing the code, it's best to make sure you know which version is being used. Versions are controlled using tags (not releases, for now)
Most recent tag is v0.1.1 and located on the cluster here:

/project/ftdc_pipeline/ftdc-picsl/pmacsPurps-v0.1.1

Within that directory, organization follows most of the organization of repos in the ftdc-picsl GitHub group, with different containers either linked or built in containers/, submit scripts in bin/ .  

Briefly, purple-mri creates a hemisphere mask and does a 10-class segmentation. There are also tools to help with other parts of analysis, like hole-filling and moving the dots to the correct spaces. The scripts in pmacsPurps work to conveniently (theoretically, anyway) wrap the the purple-mri tools with options and paths set for consistency.

We currently have a submit scripts set up to run a number of processes for ex vivo T2-weighted hemispheres. To start processing scans navigate to:

cd /project/ftdc_pipeline/ftdc-picsl/pmacsPurps-v0.1.1/bin/

  1) run purple to mask and segment: submit_purple_pipeline.sh
            Input is a file where each line is a the path of a "T2-reorient" scan in BIDS format, relative to the bids/ directory. For default processing, it should be in 
/project/ftdc_pipeline/pmc_exvivo/oriented/bids/

  2) after that's run, you can get Freesurfer to run on the hemi: submit_purple_freesurfer.sh
            Input is a csv file where each line is the path of a "T2-reorient" scan in BIDS format, relative to the bids/ directory, followed by which hemisphere it is. This script gets the hemisphere normalized to a template space, which allows us to perform vertex-level stats in a consistent space,  parcellate the cortex (see 3) below) and normalize dots to the template surface (see 4) below).
     
  3) This parcellation steps labels the gyri: submit_purple_parcellation.sh
           Same list for 2). By default, does the DKT cortical labels. Can get it set up to do other probably.
     
  4) You can also move the dots placed in the T2 reslice space to group template space: submit_purple_dots_to_surface.sh
           Input is the same list as for 2) and 3).
"Dots" are placed on the t2 images that have been reoriented and resliced. This is done manually. It's important because the dots are useful for landmarking pathological features in a consistent way. However, it's troublesome for neuroimagers because we've been told forever to avoid manual steps at all costs. In any case, it's useful to get the dots resampled to other surfaces. For now, we have one that warps 


NOTES: 
each line of the file lists should be formatted as: 
sub-{subjectLabel}/ses-{sessionLabel}/anat/sub-{subjectLabel}_ses-{sessionLabel}_{file-type_you-want_to-process}.nii.gz

Currently, the pipeline is set up to run the exvivo_t2w model, so odd behavior will occur if you try to use scans that aren't ending in _T2w.nii.gz. If other models get finalized, different versions of the submit_purple_pipeline.sh should be created. Note that over time we've collected different versions of ex vivo T2w sequences, and as far as I can tell purple should work fine on any of them.

The output of the scripts should all go inside:
/project/ftdc_pipeline/pmc_exvivo/oriented/purple_v1.4.2/exvivo_t2w
