#!/usr/bin/env bash

./nd_prediction.py /p/lscratchh/chapp1/paper_results/comm_patterns/message_race/system_quartz/n_procs_31/proc_placement_pack/msg_size_1 -o catalyst_final_eval_message_race.pkl
./nd_prediction.py /p/lscratchh/chapp1/paper_results/comm_patterns/amg2013/system_quartz/n_procs_31/proc_placement_pack/msg_size_1 -o catalyst_final_eval_amg2013.pkl
./nd_prediction.py /p/lscratchh/chapp1/paper_results/comm_patterns/mini_mcb_grid/system_quartz/n_procs_36/proc_placement_pack/interleave_option_non_interleaved/ -o catalyst_final_eval_mcb.pkl
for frac in "0" "0.25" "0.5" "0.75" "1"; 
do 
    ./nd_prediction.py /p/lscratchh/chapp1/paper_results/comm_patterns/unstructured_mesh_neighbor_logs/system_quartz/n_procs_36/proc_placement_pack/neighbor_nd_fraction_${frac}/msg_size_1/ -o catalyst_final_eval_unstructured_mesh_frac_${frac}.pkl
done
