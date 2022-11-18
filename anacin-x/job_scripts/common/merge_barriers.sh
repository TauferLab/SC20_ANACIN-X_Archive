#!/usr/bin/env bash

#SBATCH -o merge_barriers-%j.out
#SBATCH -e merge_barriers-%j.err
#SBATCH -t 00:10:00

merge_barriers_executable=$1
event_graph=$2

srun -N1 -n1 ${merge_barriers_executable} ${event_graph}
