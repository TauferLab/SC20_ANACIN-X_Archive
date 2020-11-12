#!/usr/bin/env bash

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
    results_root="/p/lscratchh/chapp1/mini_amr/debug/system_${system}/nprocs_16_2_moving_spheres/"
fi

job_scripts_root=${anacin_x_root}/anacin-x/job_scripts/mini_amr/example_problems/2_moving_spheres_16_procs/slurm/

# Execution tracing
job_script_trace_pack_procs=${job_scripts_root}/trace_nonuniform_refine_pack_procs.sh
job_script_trace_spread_procs=${job_scripts_root}/trace_nonuniform_refine_spread_procs.sh
gen_csmpi_config=${anacin_x_root}/submodules/csmpi/config/generate_config.py
csmpi_mini_amr_functions=${anacin_x_root}/submodules/csmpi/config/mpi_function_subsets/mini_amr.json

# Event graph construction
dumpi_to_graph_bin=${anacin_x_root}/submodules/dumpi_to_graph/build_${system}/dumpi_to_graph
dumpi_to_graph_config=${anacin_x_root}/submodules/dumpi_to_graph/config/dumpi_and_csmpi_barrier_only.json
job_script_build_graph=${job_scripts_root}/build_graph.sh

# Event graph postprocessing
merge_barriers_script=${anacin_x_root}/anacin-x/event_graph_analysis/merge_barriers.py
job_script_merge_barriers=${job_scripts_root}/merge_barriers.sh

# Slice extraction
extract_slices_script=${anacin_x_root}/anacin-x/event_graph_analysis/extract_slices.py
slicing_policy=${anacin_x_root}/anacin-x/event_graph_analysis/slicing_policies/barrier_delimited_full.json
job_script_extract_slices=${job_scripts_root}/extract_slices.sh
n_procs_extract_slices=${n_procs_per_node}
n_nodes_extract_slices=$(echo "(${n_procs_extract_slices} + ${n_procs_per_node} - 1)/${n_procs_per_node}" | bc)

# Error check
job_script_check_errors=${job_scripts_root}/check_errors.py

# Run parameters
#barrier_schemes=(1 2)
#proc_placement=("pack")
#load_balancing_policies=(0 1 2)
#refinement_levels=(1 2 4)
#run_idx_low=1
#run_idx_high=4

barrier_schemes=(2)
proc_placement=("pack")
load_balancing_policies=(1)
refinement_levels=(4)
run_idx_low=51
run_idx_high=100

for barrier_scheme in ${barrier_schemes[@]};
do
    for proc_placement in ${proc_placement[@]};
    do
        for n_refine_level in ${refinement_levels[@]};
        do
            for lb in ${load_balancing_policies[@]};
            do
                # Comm pattern proxy app
                app=${anacin_x_root}/apps/miniAMR/build_${system}_barrier_scheme_${barrier_scheme}/ma.x

                echo "Launching jobs for: barrier scheme: ${barrier_scheme}, proc. placement = ${proc_placement}, # levels of mesh refinement = ${n_refine_level}, load balancing policy = ${lb}"
                runs_root=${results_root}/non_uniform_refine/barrier_scheme_${barrier_scheme}/proc_placement_${proc_placement}/n_refine_${n_refine_level}/load_balancing_${lb}/

                # Launch intra-execution jobs
                kdts_job_deps=()
                for run_idx in `seq -f "%03g" ${run_idx_low} ${run_idx_high}`; 
                do
                    # Set up results dir
                    run_dir=${runs_root}/run_${run_idx}/
                    mkdir -p ${run_dir}
                    cd ${run_dir}
                    
                    # Generate CSMPI configuration
                    csmpi_dir=${run_dir}/csmpi/
                    csmpi_config=${run_dir}/csmpi_config.json
                    ${gen_csmpi_config} -o ${csmpi_config} -f ${csmpi_mini_amr_functions} -d ${csmpi_dir} 

                    # Trace execution
                    if [ ${proc_placement} == "pack" ]; then
                        trace_stdout=$( sbatch -N1 ${job_script_trace_pack_procs} ${app} ${csmpi_config} ${n_refine_level} ${lb}) 
                    elif [ ${proc_placement} == "spread" ]; then
                        trace_stdout=$( sbatch -N16 ${job_script_trace_spread_procs} ${app} ${csmpi_config} ${n_refine_level} ${lb})
                    fi
                    trace_job_id=$( echo ${trace_stdout} | sed 's/[^0-9]*//g' )
                    echo "Launching tracing job"
                    
                    # Build event graph
                    build_graph_stdout=$( sbatch -N1 --dependency=afterok:${trace_job_id} ${job_script_build_graph} 16 ${dumpi_to_graph_bin} ${dumpi_to_graph_config} ${run_dir} )
                    #build_graph_stdout=$( sbatch -N1 ${job_script_build_graph} 16 ${dumpi_to_graph_bin} ${dumpi_to_graph_config} ${run_dir} )
                    build_graph_job_id=$( echo ${build_graph_stdout} | sed 's/[^0-9]*//g' )
                    event_graph=${run_dir}/event_graph.graphml
                    echo "Launching event graph construction job"

                    # Merge adjacent barriers
                    merge_barriers_stdout=$( sbatch -N1 --dependency=afterok:${build_graph_job_id} ${job_script_merge_barriers} ${merge_barriers_script} ${event_graph} )
                    merge_barriers_job_id=$( echo ${merge_barriers_stdout} | sed 's/[^0-9]*//g' )
                    merged_event_graph=${run_dir}/event_graph_merged_barriers.graphml
                    echo "Launching event graph postprocessing job"
                        
                    # Extract slices
                    extract_slices_stdout=$( sbatch -N${n_nodes_extract_slices} --dependency=afterok:${merge_barriers_job_id} ${job_script_extract_slices} ${n_procs_extract_slices} ${extract_slices_script} ${merged_event_graph} ${slicing_policy} )
                    #extract_slices_stdout=$( sbatch -N${n_nodes_extract_slices} ${job_script_extract_slices} ${n_procs_extract_slices} ${extract_slices_script} ${merged_event_graph} ${slicing_policy} )
                    extract_slices_job_id=$( echo ${extract_slices_stdout} | sed 's/[^0-9]*//g' ) 
                    echo "Lauching slice extraction job"
                    
                    # Check errors
                    check_errors_stdout=$(sbatch -N1 --dependency=afterok:${extract_slices_job_id} ${job_script_check_errors} ${run_dir})
                    check_errors_job_id=$( echo ${check_errors_stdout} | sed 's/[^0-9]*//g' ) 
                    echo "Launching error checking job"
                        
                    # Accumulate dependency jobs for compute KDTS job
                    kdts_job_deps+=(${check_errors_job_id})
                done # runs
            done # load balancing policy
        done # refinement levels
    done # proc placement
done # barrier scheme
