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

Use absolute paths, as these have to be mounted in the container. Participant BIDS preproc data
should exist under /path/to/bids.

Using the options below, specify paths on the local file system. These will be bound automatically
to locations inside the container. If needed, you can add extra mount points with '-B'.

prep args after the '--' should reference paths within the container. For example, if
you want to use '--config-file FILE', FILE should be a path inside the container.

Currently installed versions:

`ls -1 ${repoDir}/containers | grep ".sif"`


Required args:

  -o /path/to/input-output directory
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

  -e VAR=value[,VAR=value,...,VAR=value]
     Comma-separated list of environment variables to pass to singularity.

  -h
     Prints this help message.

  -k 0/1
     Kill the job in which this script runs after the container exits. This is useful for qsiprep, which sometimes leaves
     processes running after the container exits (default = $bkillJob).



*** Hard-coded configuration ***

BIDS validation is performed by default, skip by passing '--skip-bids-validation' in the prep args.

The singularity module sets the singularity temp dir to be on /scratch. To avoid conflicts with other jobs,
the script makes a temp dir specifically for this prep job under /scratch. By default it is removed after
the prep finishes, but this can be disabled with '-c 0'.

The singularity command includes '--no-home', which avoids mounting the user home directory. This prevents caching
or config files in the user home directory from conflicting with those inside the container.

The actual call to the container is equivalent to

<purple> \\
  
  [addl args] \\
  

where [addl args] are anything following `--` in the call to this script.

*** Multi-threading and memory use ***

The number of available cores (numProcs) is derived from the environment variable \${LSB_DJOB_NUMPROC},
which is the number of slots reserved in the call to bsub. If numProcs > 1, we pass to the prep
'--nthreads numProcs --omp-nthreads numProcs'. This default may be overriden by passing the two options above as prep args.

Individual workflows may differ in performance, some may benefit from '--nthreads numProcs --omp-nthreads (numProcs - 1)',
enabling one core to run another task in parallel while a multi-threaded process uses the rest. However, in practice the
most efficient method relies upon numProcs, the host environment, and the total number of processors and jobs.

The performance gains of multi-threading fall off sharply with omp-nthreads > 8. In some contexts, it may be possible
to run jobs in parallel, eg with '--nthreads 16 --omp-nthreads 8'.

Memory use is not controlled by this script, as it is not simple to parse from the job environment. The
maximum memory (in Mb) used by the preps can be controlled with '--mem-mb'. The amount of memory required will
depend on the size of the input data, the processing options selected, and the number of threads used.


*** Additional prep args ***

See usage for the individual programs. At a minimum, you will need to set '--participant_label <participant>'.

"
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

userBindPoints=""

containerVersion=""

singularityEvars=""

while getopts "B:c:e:f:g:i:k:m:o:r:t:v:h" opt; do
  case $opt in
    B) userBindPoints=$OPTARG;;
    c) cleanupTmp=$OPTARG;;
    e) singularityEvars=$OPTARG;;
    h) help; exit 1;;
    i) bidsDir=$OPTARG;;
    k) bkillJob=$OPTARG;;
    o) outputDir=$OPTARG;;
    r) out_file_root=$OPTARG;;
    v) containerVersion=$OPTARG;;
    \?) echo "Unknown option $OPTARG"; exit 2;;
    :) echo "Option $OPTARG requires an argument"; exit 2;;
  esac
done

shift $((OPTIND-1))

whichPrep="docker_hippogang_exvivo_segm"

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

if [[ ! -d "$bidsDir" ]]; then
  echo "Cannot find input directory $bidsDir"
  exit 1
fi

if [[ ! -d "$outputDir" ]]; then
  mkdir -p "$outputDir"
fi

if [[ ! -d "${outputDir}" ]]; then
  echo "Could not find or create output directory ${outputDir}"
  exit 1
fi


# Set a job-specific temp dir
if [[ ! -d "$SINGULARITY_TMPDIR" ]]; then
  echo "Setting SINGULARITY_TMPDIR=/scratch"
  export SINGULARITY_TMPDIR=/scratch
fi

jobTmpDir=$( mktemp -d -p ${SINGULARITY_TMPDIR} ${whichPrep}.${LSB_JOBID}.XXXXXXXX.tmpdir )



if [[ ! -d "$jobTmpDir" ]]; then
  echo "Could not create job temp dir ${jobTmpDir}"
  exit 1
fi

MPLCONFIGDIR=${jobTmpDir}/MPLCONFIGDIR

if [[ ! -d "$MPLCONFIGDIR" ]]; then
  mkdir -p "$MPLCONFIGDIR"
fi

if [[ ! -d "$MPLCONFIGDIR" ]]; then
  echo "Could not create job temp dir ${MPLCONFIGDIR}"
  exit 1
fi
# Not all software uses TMPDIR
# module DEV/singularity sets SINGULARITYENV_TMPDIR=/scratch
# We will make a temp dir there and bind to /tmp in the container
export SINGULARITYENV_TMPDIR="/tmp"

# shuts up a warning message about mplconfigdir
export SINGULARITYENV_MPLCONFIGDIR="/tmp"


# singularity args
singularityArgs="--cleanenv \
  --no-home \
  --pwd / \
  -B ${jobTmpDir}:/tmp \
  -B ${bidsDir}:/data/exvivo "
  

numProcs=$LSB_DJOB_NUMPROC
numOMPThreads=$LSB_DJOB_NUMPROC


if [[ -n "$userBindPoints" ]]; then
  singularityArgs="$singularityArgs \
  -B $userBindPoints"
fi

if [[ -n "$singularityEvars" ]]; then
  singularityArgs="$singularityArgs \
  --env $singularityEvars"
fi

purpleMRIargs="$*"
purpleMRIargs=$(echo $purpleMRIargs | sed 's/--//')

echo "
--- args passed through to purpleMRI  ---
$*
---
"

echo "
--- Script options ---
brainQCnet image       : $image
BIDS directory         : $bidsDir
saved_models directory : $saved_models_dir
Output directory       : $outputDir
Cleanup temp           : $cleanupTmp
User bind points       : $userBindPoints
User environment vars  : $singularityEvars
Number of cores        : $numProcs
OMP threads            : $numOMPThreads
---
"

echo "
--- Container details ---"
singularity inspect $image
echo "---
"

cmd="singularity exec \
  --nv \
  $singularityArgs \
  $image \
  bash /src/commands_nnunet_inference.sh $purpleMRIargs "

echo "
--- purple command ---
$cmd
---
"



# function to clean up tmp and report errors at exit
function cleanup {
  EXIT_CODE=$?
  LAST_CMD=${BASH_COMMAND}
  set +e # disable termination on error

  if [[ "$cleanupTmp" =~ ^/ ]]; then
    echo "Copying temp dir ${jobTmpDir} to ${cleanupTmp}"
    mkdir -p $(dirname ${cleanupTmp})
    cp -r ${jobTmpDir} ${cleanupTmp}
    rm -rf ${jobTmpDir}
  elif [[ "$cleanupTmp" == "1" ]]; then
    echo "Removing temp dir ${jobTmpDir}"
    rm -rf ${jobTmpDir}
  else
    echo "Leaving working directory ${jobTmpDir}"
  fi

  if [[ ${EXIT_CODE} -gt 0 ]]; then
    echo "
  $0 EXITED ON ERROR - PROCESSING MAY BE INCOMPLETE"
    echo "
  The command \"${LAST_CMD}\" exited with code ${EXIT_CODE}
"
  fi

  exit $EXIT_CODE
}

trap cleanup EXIT

# Exits, triggering cleanup, on CTRL+C
function sigintCleanup {
   exit $?
}

trap sigintCleanup SIGINT

$cmd
singExit=$?


if [[ $singExit -ne 0 ]]; then
  echo "Container exited with non-zero code $singExit"
fi

if [[ $bkillJob -eq 1 ]]; then
  # qsiprep plotting code leaves processes running, so we have to kill the job
  echo "Exiting by killing job ${LSB_JOBID}"
  bkill $LSB_JOBID
fi

exit $singExit
