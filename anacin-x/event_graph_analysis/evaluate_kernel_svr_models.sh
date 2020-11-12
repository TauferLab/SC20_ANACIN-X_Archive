#!/usr/bin/env bash

pfs_root="/p/lscratchh/chapp1/"
inputs_dir="${pfs_root}/thesis_results/comm_patterns/kernel_matrices/"

results_dir="${pfs_root}/thesis_results/comm_patterns/svr_models/"
mkdir -p ${results_dir}

ega_root="$HOME/ANACIN-X/anacin-x/event_graph_analysis/"
eval_script="${ega_root}/evaluate_model.py"

target_param="nd_percentage_msg"
n_folds=10
n_repeats=10

comm_patterns=("message_race" 
               "amg2013" 
               "mcb_grid" 
               "unstructured_mesh_0"
               "unstructured_mesh_25"
               "unstructured_mesh_50"
               "unstructured_mesh_75"
               "unstructured_mesh_100"
               "unstructured_mesh_all"
              )
#comm_patterns=("message_race" 
#               "amg2013" 
#               "mcb_grid" 
#              )
#comm_patterns=("unstructured_mesh_0"
#               "unstructured_mesh_25"
#               "unstructured_mesh_50"
#               "unstructured_mesh_75"
#               "unstructured_mesh_100"
#              )

graph_kernels=("vertex_histogram" "subtree_wl" "graphlet_sampling" "neighborhood_hash" "odd_sth" "shortest_path" "shortest_path_lableled")

for cp in ${comm_patterns[@]};
do
    for gk in ${graph_kernels[@]};
    do
        kernel_matrices="${inputs_dir}/kernel_matrices_${cp}_${gk}.pkl"
        run_params="${inputs_dir}/run_params_${cp}_${gk}.pkl"
        model_output="${results_dir}/svr_results_${cp}_${gk}.pkl"

        #if [[ -f ${kernel_matrices} && -f ${run_params} && ! -f ${model_output} ]]; then
        if [[ -f ${kernel_matrices} && -f ${run_params} ]]; then
            echo "Submitting job to train/eval. kernel-SVR model for comm. pattern: ${cp} using graph kernel: ${gk}"
            sbatch -N1 ${eval_script} --kernel_matrices ${kernel_matrices} --graph_labels ${run_params} --predict ${target_param} --out ${model_output} --n_folds ${n_folds} --n_repeats ${n_repeats}
        fi
    done
done

