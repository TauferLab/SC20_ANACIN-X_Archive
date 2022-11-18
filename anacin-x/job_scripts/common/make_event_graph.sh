#!/usr/bin/env bash

#SBATCH -o make_event_graph-%j.out
#SBATCH -e make_event_graph-%j.err
#SBATCH -t 1:00:00

n_nodes=$1
n_procs=$2
dumpi_to_graph_executable=$3
dumpi_to_graph_config=$4
results_dir=$5

srun -N${n_nodes} -n${n_procs} ${dumpi_to_graph_executable} ${dumpi_to_graph_config} ${results_dir}
