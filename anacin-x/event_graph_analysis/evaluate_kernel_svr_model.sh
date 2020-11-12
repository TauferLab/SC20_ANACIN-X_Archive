#!/usr/bin/env bash

comm_pattern=$1
graph_kernel=$2
n_folds=$3
n_reps=$4
target_param="nd_percentage_msg"

pfs_root="/p/lscratchh/chapp1/"
inputs_dir="${pfs_root}/thesis_results/comm_patterns/kernel_matrices/"
results_dir="${pfs_root}/thesis_results/comm_patterns/svr_models/"
mkdir -p ${results_dir}

ega_root="$HOME/ANACIN-X/anacin-x/event_graph_analysis/"
eval_script="${ega_root}/evaluate_model.py"

kernel_matrices="${inputs_dir}/kernel_matrices_${comm_pattern}_${graph_kernel}.pkl"
run_params="${inputs_dir}/run_params_${comm_pattern}_${graph_kernel}.pkl"
model_output="${results_dir}/svr_results_${comm_pattern}_${graph_kernel}.pkl"
sbatch -N1 ${eval_script} --kernel_matrices ${kernel_matrices} --graph_labels ${run_params} --predict ${target_param} --out ${model_output} --n_folds ${n_folds} --n_repeats ${n_reps}
