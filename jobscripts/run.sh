#!/bin/bash 
set -x

###############################################################################
# Helper functions
###############################################################################

function quit {
    echo "$1" >&2
    exit 1
}

###############################################################################
# Derived options
###############################################################################

# We build the command line in a string before executing it, and it's very hard
# to get this to work if the executable name contains spaces, so we punt.
if [[ "$EXECUTABLE" != "${EXECUTABLE%[[:space:]]*}" ]]; then
    quit "Cannot handle spaces in executable name"
fi

# Command-line arguments are passed directly to the job script. We need to
# accept multiple arguments separated by whitespace, and pass them through the
# environment. It is very hard to properly handle spaces in arguments in this
# mode, so we punt.
for (( i = 1; i <= $#; i++ )); do
    if [[ "${!i}" != "${!i%[[:space:]]*}" ]]; then
        quit "Cannot handle spaces in command line arguments"
    fi
done
export ARGS=$@

export WALLTIME="$(printf "%02d:%02d:00" $((MINUTES/60)) $((MINUTES%60)))"

if [ "$(uname)" == "Darwin" ]; then
    export DYLD_LIBRARY_PATH="${DYLD_LIBRARY_PATH:-}:$LEGION_DIR/bindings/regent/"
    if [[ ! -z "${HDF_ROOT:-}" ]]; then
        export DYLD_LIBRARY_PATH="${DYLD_LIBRARY_PATH:-}:$HDF_ROOT/lib"
    fi
else
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}:$LEGION_DIR/bindings/regent/"
    if [[ ! -z "${HDF_ROOT:-}" ]]; then
        export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}:$HDF_ROOT/lib"
    fi
fi


# Make sure the number of requested ranks is divisible by the number of nodes.
export NUM_NODES=$(( NUM_RANKS / RANKS_PER_NODE ))
if (( NUM_RANKS % RANKS_PER_NODE > 0 )); then
   export NUM_NODES=$(( NUM_NODES + 1 ))
fi

export NUM_RANKS=$(( NUM_NODES * RANKS_PER_NODE ))

export LOCAL_RUN=0

export LEGION_FREEZE_ON_ERROR="$DEBUG"

###############################################################################
# Machine-specific handling
###############################################################################

function run_chizuru {
     if (( NUM_NODES > 1 )); then
         quit "Too many nodes requested"
     fi
    # Overrides for local, GPU run
    LOCAL_RUN=1
    USE_CUDA=1
    ##added by MK
    CORES_PER_NODE=20
    GPUS_PER_NODE=4
    FB_PER_GPU=4000
    ##RESERVED_CORES=2
    NUMA_PER_RANK=2
    ##added by MK
    # Synthesize final command
    ##CORES_PER_NODE="$(grep ^cpu\\scores /proc/cpuinfo | uniq |  awk '{print $4}')"
    RAM_PER_NODE="$(free -m | head -2 | tail -1 | awk '{print $2}')"
    RAM_PER_NODE=$(( RAM_PER_NODE / 2 ))
    source "$HTR_DIR"/src/jobscript_shared.sh
    $COMMAND
}

 ##added by MK
function run_juwels {
   # export QUEUE="${QUEUE:-develgpus}"
   RESOURCES=
     RESOURCES=
   if [[ "$QUEUE" == "develbooster" || "$QUEUE" == "booster" ]]; then
      RESOURCES="gpu:4"
   fi
   if [[ "$QUEUE" == "batch" ]]; then
      RESOURCES="mem96"
   fi

   DEPS=
   if [[ ! -z "$AFTER" ]]; then
      DEPS="-d afterok:$AFTER"
   fi
   CORES_PER_RANK=$(( 40/$RANKS_PER_NODE ))
### sbatch the SLURM file OR
   sbatch --export=ALL \
        -N "$NUM_RANKS" -t 00:15:00 -p "$QUEUE" --gres="$RESOURCES" $DEPS \
        --ntasks-per-node="$RANKS_PER_NODE" --cpus-per-task="$CORES_PER_RANK" \
        --account="$ACCOUNT"  "$HTR_DIR"/jobscripts/ghost.slurm
## OR directly
# source "$HTR_DIR"/jobscripts/jobscript_shared.sh
#    $COMMAND

 # Resources:
# 192GB RAM per node
# Framebuffer per GPU =16 GB= 16000 MiB
# 2 NUMA domains per node
# 40 cores per NUMA domain
# 4 Tesla V100 SXM2 GPUs per node
}
 ##added by MK



###############################################################################
# Switch on machine
###############################################################################
if [[ "$(uname -n)" == *"juwels"* ]]; then
    run_juwels
elif [[ "$(uname -n)" == *"chizuru"* ]]; then
    run_chizuru
else
    echo 'Hostname not recognized; assuming local machine run w/o  GPUs'
    run_local
fi

