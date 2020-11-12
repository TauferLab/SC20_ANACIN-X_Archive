#!/usr/bin/env bash

pfs_root="/p/lscratchh/chapp1/"
data_dirs_root="${pfs_root}/thesis_results/comm_patterns/"

#data_dirs=("${data_dirs_root}/message_race_iters_10/system_catalyst/n_procs_21/proc_placement_pack/msg_size_1/" 
#           "${data_dirs_root}/amg2013/system_catalyst/n_procs_21/proc_placement_pack/msg_size_1/" 
#           "${data_dirs_root}/mcb_grid/system_catalyst/n_procs_21/proc_placement_pack/"
#          )

#data_dirs=("${data_dirs_root}/unstructured_mesh/system_quartz/n_procs_64/proc_placement_pack/msg_size_1/top_ndp_0/"
#           "${data_dirs_root}/unstructured_mesh/system_quartz/n_procs_64/proc_placement_pack/msg_size_1/top_ndp_25/"
#           "${data_dirs_root}/unstructured_mesh/system_quartz/n_procs_64/proc_placement_pack/msg_size_1/top_ndp_50/"
#           "${data_dirs_root}/unstructured_mesh/system_quartz/n_procs_64/proc_placement_pack/msg_size_1/top_ndp_75/"
#           "${data_dirs_root}/unstructured_mesh/system_quartz/n_procs_64/proc_placement_pack/msg_size_1/top_ndp_100/"
#          )

data_dirs=("${data_dirs_root}/unstructured_mesh/system_quartz/n_procs_64/proc_placement_pack/msg_size_1/")

#comm_patterns=("unstructured_mesh_0",
#               "unstructured_mesh_25"
#               "unstructured_mesh_50"
#               "unstructured_mesh_75"
#               "unstructured_mesh_100"
#              )

comm_patterns=("unstructured_mesh_all")

#comm_patterns=("message_race" 
#               "amg2013" 
#               "mcb_grid"
#              )


graph_kernels=("subtree_wl" 
               "vertex_histogram"
               "graphlet_sampling" 
               "neighborhood_hash"
              )

#data_dirs=("${data_dirs_root}/message_race_iters_10/system_catalyst/n_procs_21/proc_placement_pack/msg_size_1/" 
#          )
#comm_patterns=("message_race" 
#              )
#graph_kernels=("subtree_wl" 
#              )

ega_root="$HOME/ANACIN-X/anacin-x/event_graph_analysis/"
graph_kernel_script="${ega_root}/graph_kernels.py"


output_root="${pfs_root}/thesis_results/comm_patterns/kernel_matrices/"
max_run_idx=100

for ((i=0;i<${#data_dirs[@]};++i));
do
    dd=${data_dirs[i]}
    cp=${comm_patterns[i]}
    for gk in ${graph_kernels[@]};
    do
        echo "Submitting job to compute kernel matrix for comm. pattern: ${cp} using graph kernel: ${gk}"
        kernel_matrices_output="${output_root}/kernel_matrices_${cp}_${gk}.pkl"
        run_params_output="${output_root}/run_params_${cp}_${gk}.pkl"
        sbatch -N1 ${graph_kernel_script} --base_dir ${dd} --run_dir_depth 2 --kernels ${gk} --max_run_idx ${max_run_idx} --kernel_matrices_output ${kernel_matrices_output} --run_params_output ${run_params_output} --kernel_matrices_cache ${kernel_matrices_output} --wl_iters 2 4 8 16 --graphlet_sampling_dims 3 5 7 --graphlet_sampling_counts 10 100 1000
    done
done

