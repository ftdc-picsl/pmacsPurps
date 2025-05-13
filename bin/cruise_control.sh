#!/bin/bash

module unload singularity
module load singularity/3.8.3

bkillJob=0
cleanupTmp="1" # can be a path
useGPU=0

scriptPath=$(readlink -f "$0")
scriptDir=$(dirname "${scriptPath}")
# Repo base dir under which we find bin/ and containers/
repoDir=${scriptDir%/bin}

function usage() {
  echo " This function is largely outdated, with much of its functionality now achieved using freesurfer."
  echo " But, I left this here for posterity and in case it becomes useful for some other reason."
  echo "" 
  echo ""
  echo "Usage:
  $0 [-h] [-B src:dest,...,src:dest] [-c 1/0] [-e VAR=value]  \\
     -v version -i /path/to/bids -o /path/to/outputDir -- [prep args]

  Use the -h option to see detailed help.

"
}

function help() {
    usage
  echo "This script handles various configuration options and bind points needed to run purple-mri 
(https://github.com/Pulkit-Khandelwal/purple-mri/) on the cluster. Requires singularity (module load singularity/3.8.3).

Use absolute paths, as these have to be mounted in the container. Participant segmentation preproc data
should exist under /path/to/data/data_for_inference.

Using the options below, specify paths on the local file system. These will be bound automatically
to locations inside the container. If needed, you can add extra mount points with '-B'.

Currently installed versions:

`ls -1 ${repoDir}/containers | grep ".sif"`

Required args:

  -d /path/to/input-output directory
    directory on the local file system with a child data_for_inference directory that contains the 0000.nii.gz file. Will be bound to /data/exvivo inside the container.
  
  -v version
    container version. The script will look for containers/brainQCnet-[version].sif.


Options:

  -B src:dest[,src:dest,...,src:dest]
     Use this to add mount points to bind inside the container, that aren't handled by other options.
     'src' is an absolute path on the local file system and 'dest' is an absolute path inside the container.
     Several bind points are always defined inside the container including \$HOME, \$PWD (where script is
     executed from), and /tmp (more on this below). Additionally, BIDS input (-i), output (-o), and FreeSurfer
     output dirs (-f) are bound automatically.

  -c 1/0 | /path/to/save/tmpdir
     Cleanup the working dir after running the prep (default = $cleanupTmp). This is different from the prep
     option '--clean-workdir', which deletes the contents of the working directory BEFORE running anything.

     If the argument is a path, the working dir will be copied there. This should be a path on the local file
     system.

  -h
     Prints this help message.

  -k 0/1
     Kill the job in which this script runs after the container exits. This is useful for qsiprep, which sometimes leaves
     processes running after the container exits (default = $bkillJob).



*** Hard-coded configuration ***

The singularity module sets the singularity temp dir to be on /scratch. To avoid conflicts with other jobs,
the script makes a temp dir specifically for this prep job under /scratch. By default it is removed after
the prep finishes, but this can be disabled with '-c 0'.

The singularity command includes '--no-home', which avoids mounting the user home directory. This prevents caching
or config files in the user home directory from conflicting with those inside the container.

The actual call to the container is equivalent to

<purple> \\

"
}
if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

userBindPoints=""

containerVersion=""

singularityEvars=""

while getopts "B:c:i:k:d:v:h" opt; do
  case $opt in
    B) userBindPoints=$OPTARG;;
    c) cleanupTmp=$OPTARG;;
    h) help; exit 1;;
    k) bkillJob=$OPTARG;;
    d) ioDir=$OPTARG;;
    v) containerVersion=$OPTARG;;
    \?) echo "Unknown option $OPTARG"; exit 2;;
    :) echo "Option $OPTARG requires an argument"; exit 2;;
  esac
done

shift $((OPTIND-1))

whichPrep="docker_nighres"

image="${repoDir}/containers/${whichPrep}-${containerVersion}.sif"

if [[ ! -f $image ]]; then
  echo "Cannot find requested container $image"
  exit 1
fi

if [[ -z "${LSB_JOBID}" ]]; then
  echo "This script must be run within a (batch or interactive) LSF job"
  exit 1
fi

sngl=$( which singularity ) ||
    ( echo "Cannot find singularity executable. Try module load singularity/3.8.3"; exit 1 )

if [[ ! -d "$ioDir" ]]; then
  echo "Cannot find  directory $ioDir"
  exit 1
fi

# singularity args
singularityArgs="--cleanenv \
  --no-home \
  --pwd / \
  -B ${ioDir}:/data/cruise_files/:rw "

echo "
--- Container details ---"
singularity inspect $image
echo "---
"

cmd="singularity exec \
  $singularityArgs \
  $image \
  bash /data/prepare_cruise_files.sh "

echo "
--- purple cruise command ---
$cmd
---
"
$cmd

chgrp -R ftdclpc ${ioDir}
chmod -R 774 ${ioDir}