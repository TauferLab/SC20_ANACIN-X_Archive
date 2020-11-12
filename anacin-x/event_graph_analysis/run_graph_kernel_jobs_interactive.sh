#!/usr/bin/env bash

data_dirs=("/p/lscratchh/chapp1/thesis_results/comm_patterns/message_race_iters_10/system_catalyst/n_procs_21/proc_placement_pack/msg_size_1/" "/p/lscratchh/chapp1/thesis_results/comm_patterns/amg2013/system_catalyst/n_procs_21/proc_placement_pack/msg_size_1/" "/p/lscratchh/chapp1//thesis_results/comm_patterns/mcb_grid/system_catalyst/n_procs_21/proc_placement_pack/")
comm_patterns=("message_race" "amg2013" "mcb_grid")
graph_kernels=("vertex_histogram" "subtree_wl" "graphlet_sampling" "odd_sth" "neighborhood_hash" "shortest_path" "shortest_path_labeled")

#data_dirs=("/p/lscratchh/chapp1/thesis_results/comm_patterns/message_race_iters_10/system_catalyst/n_procs_21/proc_placement_pack/msg_size_1/")
#comm_patterns=("message_race")
#graph_kernels=("vertex_histogram")

ega_root="$HOME/ANACIN-X/anacin-x/event_graph_analysis/"
graph_kernel_job="${ega_root}/compute_kernel_matrices.sh"
build_model_job="${ega_root}/build_graph_kernel_model.sh"

for ((i=0;i<${#data_dirs[@]};++i));
do
    curr_data_dir=${data_dirs[i]}
    curr_comm_pattern=${comm_patterns[i]}
    for gk in ${graph_kernels[@]};
    do
        echo "${curr_data_dir} ${curr_comm_pattern} ${gk}"
        ${graph_kernel_job} ${curr_data_dir} ${curr_comm_pattern} ${gk}
        ${gk_job_id} ${build_model_job} ${curr_comm_pattern} ${gk}
    done
done

