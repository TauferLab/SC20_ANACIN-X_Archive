#!/usr/bin/env bash

#SBATCH -o trace_mcb-%j.out
#SBATCH -e trace_mcb-%j.err
#SBATCH -t 1:00:00

# General execution parameters
mcb_executable=$1
# Tracing parameters
pnmpi_lib=$2
pnmpi_config=$3
pnmpi_patched_libs_dir=$4
csmpi_config=$5
# SLURM arguments
n_nodes=$6
n_procs=$7
n_tasks_per_node=$8
# MCB arguments
n_mpi_tasks_x=$9
n_mpi_tasks_y="${10}"


# Check argument validity

export OMP_NUM_THREADS=1

LD_PRELOAD=${pnmpi_lib} PNMPI_LIB_PATH=${pnmpi_patched_libs_dir} PNMPI_CONF=${pnmpi_config} CSMPI_CONFIG=${csmpi_config} srun \
     -N ${n_nodes} \
     -n ${n_procs} \
     --ntasks-per-node ${n_tasks_per_node} \
     --cpus-per-task 1 \
     ${mcb_executable} \
     --nMpiTasksX=${n_mpi_tasks_x} \
     --nMpiTasksY=${n_mpi_tasks_y} \
     --nThreadCore=1 \
     --mirrorBoundary \
     --distributedSource


    
