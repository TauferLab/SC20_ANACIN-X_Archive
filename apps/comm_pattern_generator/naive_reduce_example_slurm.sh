#!/usr/bin/env bash

run_idx_low=$1
run_idx_high=$2

# Orient ourselves
anacin_x_root=$HOME/ANACIN-X
system=$(hostname | sed 's/[0-9]*//g')
# Determine node capacity
if [ ${system} == "quartz" ]; then
    n_procs_per_node=36
elif [ ${system} == "catalyst" ]; then
    n_procs_per_node=24
fi
# Determine where to write results data (trace files, event graphs, etc.)
if [ ${system} == "quartz" ] || [ ${system} == "catalyst" ]; then
    results_root="/p/lscratchh/chapp1/comm_patterns/naive_reduce/"
fi

# Comm pattern proxy app
app=${anacin_x_root}/apps/comm_pattern_generator/build/comm_pattern_generator
job_script_trace_pack_procs=${anacin_x_root}/apps/comm_pattern_generator/trace_pattern_pack_procs.sh
job_script_trace_spread_procs=${anacin_x_root}/apps/comm_pattern_generator/trace_pattern_spread_procs.sh

# Event graph construction
dumpi_to_graph_bin=${anacin_x_root}/submodules/dumpi_to_graph/build/dumpi_to_graph
dumpi_to_graph_config=${anacin_x_root}/submodules/dumpi_to_graph/config/dumpi_only.json
job_script_build_graph=${anacin_x_root}/apps/comm_pattern_generator/build_graph.sh

# Slice extraction
extract_slices_bin=${anacin_x_root}/anacin-x/event_graph_analysis/extract_slices.py
slicing_policy=${anacin_x_root}/anacin-x/event_graph_analysis/slicing_policies/barrier_delimited_full.json
job_script_extract_slices=${anacin_x_root}/apps/comm_pattern_generator/extract_slices.sh
n_procs_extract_slices=10
n_nodes_extract_slices=$(echo "(${n_procs_extract_slices} + ${n_procs_per_node} - 1)/${n_procs_per_node}" | bc)

# Kernel distance time series computation
compute_kdts_script=${anacin_x_root}/anacin-x/event_graph_analysis/compute_kernel_distance_time_series.py
graph_kernel=${anacin_x_root}/anacin-x/event_graph_analysis/graph_kernel_policies/wlst_5iters_logical_timestamp_label.json

#proc_placement=("pack" "spread")
#run_scales=(11 21 41)
#message_sizes=(1 512 1024 2048)

#proc_placement=("pack" "spread")
#run_scales=(11 41)
#message_sizes=(1)


for proc_placement in ${proc_placement[@]};
do
    for n_procs in ${run_scales[@]};
    do
        for msg_size in ${message_sizes[@]};
        do
            for run_idx in `seq -f "%03g" ${run_idx_low} ${run_idx_high}`; 
            do
                # Set up results dir
                run_dir=${results_root}/n_procs_${n_procs}/proc_placement_${proc_placement}/msg_size_${msg_size}/run_${run_idx}/
                mkdir -p ${run_dir}
                cd ${run_dir}

                # Trace execution
                config=${anacin_x_root}/apps/comm_pattern_generator/config/naive_reduce_example_msg_size_${msg_size}.json
                if [ ${proc_placement} == "pack" ]; then
                    n_nodes_trace=$(echo "(${n_procs} + ${n_procs_per_node} - 1)/${n_procs_per_node}" | bc)
                    trace_stdout=$( sbatch -N${n_nodes_trace} ${job_script_trace_pack_procs} ${n_procs} ${app} ${config} )
                elif [ ${proc_placement} == "spread" ]; then
                    n_nodes_trace=${n_procs}
                    trace_stdout=$( sbatch -N${n_nodes_trace} ${job_script_trace_spread_procs} ${n_procs} ${app} ${config} )
                fi
                trace_job_id=$( echo ${trace_stdout} | sed 's/[^0-9]*//g' )
                
                # Build event graph
                n_nodes_build_graph=$(echo "(${n_procs} + ${n_procs_per_node} - 1)/${n_procs_per_node}" | bc)
                build_graph_stdout=$( sbatch -N${n_nodes_build_graph} --dependency=afterok:${trace_job_id} ${job_script_build_graph} ${n_procs} ${dumpi_to_graph_bin} ${dumpi_to_graph_config} ${run_dir} )
                build_graph_job_id=$( echo ${build_graph_stdout} | sed 's/[^0-9]*//g' )
                event_graph=${run_dir}/event_graph.graphml

                # Extract slices
                extract_slices_stdout=$( sbatch -N${n_nodes_extract_slices} --dependency=afterok:${build_graph_job_id} ${job_script_extract_slices} ${n_procs_extract_slices} ${extract_slices_bin} ${event_graph} ${slicing_policy} )
                extract_slices_job_id=$( echo ${extract_slices_stdout} | sed 's/[^0-9]*//g' ) 
            done
        done
    done
done
