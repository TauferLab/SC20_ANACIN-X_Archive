#!/usr/bin/env bash

run_idx_low=$1
run_idx_high=$2
perturb_msg_order=$3

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
    if [ -z "${perturb_msg_order}" ]; then
        results_root="/p/lscratchh/chapp1/thesis_results/comm_patterns/unstructured_mesh/system_${system}/"
    else
        results_root="/p/lscratchh/chapp1/thesis_results/comm_patterns/unstructured_mesh_perturbed/system_${system}/"
    fi
fi
mkdir -p ${results_root}

# Comm pattern proxy app
app=${anacin_x_root}/apps/comm_pattern_generator/build_${system}/comm_pattern_generator
if [ -z "${perturb_msg_order}" ]; then
    job_script_trace_pack_procs=${anacin_x_root}/apps/comm_pattern_generator/trace_pattern_pack_procs.sh
    job_script_trace_spread_procs=${anacin_x_root}/apps/comm_pattern_generator/trace_pattern_spread_procs.sh
else
    job_script_trace_pack_procs=${anacin_x_root}/apps/comm_pattern_generator/trace_pattern_perturbed_pack_procs.sh
    job_script_trace_spread_procs=${anacin_x_root}/apps/comm_pattern_generator/trace_pattern_spread_procs.sh
fi
config_dir=${anacin_x_root}/apps/comm_pattern_generator/config/unstructured_mesh/
job_script_write_run_params=${anacin_x_root}/anacin-x/event_graph_analysis/write_run_params.py

# Event graph construction
dumpi_to_graph_bin=${anacin_x_root}/submodules/dumpi_to_graph/build_${system}/dumpi_to_graph
dumpi_to_graph_config=${anacin_x_root}/submodules/dumpi_to_graph/config/dumpi_only.json
job_script_build_graph=${anacin_x_root}/apps/comm_pattern_generator/build_graph.sh

#proc_placement=("pack" "spread")
proc_placement=("pack")
run_scales=(64)
message_sizes=(1)
non_determinism_percentages=(10 20 30 40 50 60 70 80 90 100)
#non_determinism_percentages=(0 100)
neighbor_non_determinism_percentages=(0 25 50 75 100)
#neighbor_non_determinism_percentages=(25 50 75)

for proc_placement in ${proc_placement[@]};
do
    for n_procs in ${run_scales[@]};
    do
        for msg_size in ${message_sizes[@]};
        do
            for top_ndp in ${neighbor_non_determinism_percentages[@]};
            do
                for msg_ndp in ${non_determinism_percentages[@]}
                do
                    echo "Launching jobs for: proc. placement = ${proc_placement}, # procs. = ${n_procs}, msg. size = ${msg_size}, Topology DN% = ${top_ndp}, Message ND% = ${msg_ndp}"
                    runs_root=${results_root}/n_procs_${n_procs}/proc_placement_${proc_placement}/msg_size_${msg_size}/top_ndp_${top_ndp}/msg_ndp_${msg_ndp}/

                    for run_idx in `seq -f "%03g" ${run_idx_low} ${run_idx_high}`; 
                    do
                        # Set up results dir
                        run_dir=${runs_root}/run_${run_idx}/
                        mkdir -p ${run_dir}
                        cd ${run_dir}
                        # Define communication pattern configuration
                        config=${config_dir}/top_ndp_${top_ndp}/procs_4x4x4_ndp_${msg_ndp}_msg_size_${msg_size}.json
                        # Check that all required files exist
                        if [[ -a ${job_script_trace_pack_procs} && -a ${job_script_trace_spread_procs} && -a ${app} && -a ${config} && -a ${job_script_build_graph} && -a ${dumpi_to_graph_bin} && -a ${dumpi_to_graph_config} ]]; then
                            sbatch -N1 ${job_script_write_run_params} --pattern "unstructured_mesh" --n_proc ${n_procs} --proc_placement ${proc_placement} --msg_size ${msg_size} --nd_percentage_msg ${msg_ndp} --nd_percentage_top ${top_ndp}
                            # Trace communication pattern execution
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
                        fi
                    done # runs
                done # non-determinism percentages
            done # neighbor non-determinism percentages
        done # msg sizes
    done # num procs
done # proc placement
