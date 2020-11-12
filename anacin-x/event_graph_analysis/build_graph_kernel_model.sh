#!/usr/bin/env bash

#SBATCH -o svr-%j.out
#SBATCH -e svr-%j.out
#SBATCH -t 12:00:00

comm_pattern_name=$1
graph_kernel=$2

pfs_root="/p/lscratchh/chapp1/"
inputs_dir="${pfs_root}/thesis_results/comm_patterns/kernel_matrices/"
results_dir="${pfs_root}/thesis_results/comm_patterns/svr_models/"
mkdir -p ${results_dir}
kernel_matrices="${inputs_dir}/kernel_matrices_${comm_pattern_name}_${graph_kernel}.pkl"
run_params="${inputs_dir}/run_params_${comm_pattern_name}_${graph_kernel}.pkl"
out="${results_dir}/svr_results_${comm_pattern_name}_${graph_kernel}.pkl"

./models.py --kernel_matrices ${kernel_matrices} --graph_labels ${run_params} --predict "nd_percentage_msg" --output ${out} --n_folds 10 --n_repeats 100
