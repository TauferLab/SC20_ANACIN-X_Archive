#!/usr/bin/env bash

#SBATCH -o gk-%j.out
#SBATCH -e gk-%j.out
#SBATCH -t 12:00:00

comm_pattern_dir=$1
comm_pattern_name=$2
graph_kernel=$3

run_dir_depth=1
max_run_idx=100

results_dir="/p/lscratchh/chapp1/thesis_results/comm_patterns/kernel_matrices/"
mkdir -p ${results_dir}
cache="${results_dir}/kernel_matrices_${comm_pattern_name}_${graph_kernel}.pkl"
out="${results_dir}/kernel_matrices_${comm_pattern_name}_${graph_kernel}.pkl"
run_params_out="${results_dir}/run_params_${comm_pattern_name}_${graph_kernel}.pkl"


./graph_kernels.py --base_dir ${comm_pattern_dir} --run_dir_depth ${run_dir_depth} --kernels ${graph_kernel} --max_run_idx ${max_run_idx} --kernel_matrices_cache ${cache} --kernel_matrices_output ${out} --run_params_output ${run_params_out} --wl_iters 2 4 8 --graphlet_sampling_dims 3 5 --graphlet_sampling_counts 10 100

