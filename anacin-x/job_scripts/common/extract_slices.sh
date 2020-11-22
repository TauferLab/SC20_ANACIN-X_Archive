#!/usr/bin/env bash

#SBATCH -o extract_slices-%j.out
#SBATCH -e extract_slices-%j.err
#SBATCH -t 01:00:00

n_procs=$1
extract_slices_executable=$2
event_graph=$3
slicing_policy=$4

slice_dir_name="slices_$(basename ${slicing_policy} .json)"

# Determine number of nodes we need to run on
system=$(hostname | sed 's/[0-9]*//g')
if [ ${system} == "quartz" ]; then
    n_procs_per_node=36
elif [ ${system} == "catalyst" ]; then
    n_procs_per_node=24
fi
n_nodes=$(echo "(${n_procs} + ${n_procs_per_node} - 1)/${n_procs_per_node}" | bc)

srun -N${n_nodes} -n${n_procs} ${extract_slices_executable} ${event_graph} ${slicing_policy} -o ${slice_dir_name}
