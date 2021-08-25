#!/bin/bash -x 
#SBATCH --job-name=prometeot
#SBATCH --output=test-out.%j
#SBATCH --error=test-err.%j

if [[ "$QUEUE" == "batch" ]]; then
   USE_CUDA=0
   CORES_PER_NODE=48
   NUMA_PER_RANK=2
   RAM_PER_NODE=70000

elif [[ "$QUEUE" == "develbooster" || "$QUEUE" == "booster" ]]; then
# GASNET_BACKTRACE=1
   USE_CUDA=1
   CORES_PER_NODE=40
   NUMA_PER_RANK=2
   RAM_PER_NODE=70000
   GPUS_PER_NODE=4
   FB_PER_GPU=13000

# Resources:
# 192GB RAM per node
# Framebuffer per GPU =16 GB= 16000 MiB
# 2 NUMA? domains per node
# 40 cores per NUMA domain
# 4 Tesla V100 SXM2 GPUs per node
else
    echo "Unrecognized queue $QUEUE" >&2
    exit 1
fi

module purge
module load GCC/9.3.0
module load OpenMPI/4.1.0rc1
module load CUDA/11.0
module load Python/3.8.5
# export GASNET_BACKTRACE=1

## cd $SLURM_SUBMIT_DIR
source "$HTR_DIR"/jobscripts/jobscript_shared.sh

## nvidia-smi 

   srun -n "$NUM_RANKS" --ntasks-per-node="$RANKS_PER_NODE" --cpus-per-task="$CORES_PER_RANK" \
     --export=ALL \
     $COMMAND -ll:show_rsrv

