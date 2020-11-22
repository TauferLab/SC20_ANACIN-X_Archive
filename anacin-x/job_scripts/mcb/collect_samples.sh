#!/usr/bin/env bash

sample_idx_low=$1
sample_idx_high=$2

n_nodes=1
n_procs=16
n_procs_per_node=16
n_mpi_tasks_x=4
n_mpi_tasks_y=4

source ../../base_vars.sh

mcb_executable="${HOME}/mcb-20130723/src/MCBenchmark.exe"
results_root_dir="/p/lscratchh/chapp1/mcb/"

job_scripts_root="${anacin_x_root}/anacin-x/job_scripts/"

trace_job_script="${job_scripts_root}/mcb/sample_execution.sh"
build_graph_job_script="${job_scripts_root}/common/build_graph.sh"

gen_csmpi_config_script=${anacin_x_root}/submodules/csmpi/config/generate_config.py
csmpi_mcb_functions=${anacin_x_root}/submodules/csmpi/config/mpi_function_subsets/mcb.json

# Locations of PnMPI stuff for composing the various tracing modules 
pnmpi_lib=${anacin_x_root}/submodules/PnMPI/build_catalyst/lib/libpnmpi.so
pnmpi_patched_libs_dir=${anacin_x_root}/anacin-x/pnmpi/patched_libs_catalyst/
pnmpi_config=${anacin_x_root}/anacin-x/pnmpi/configs/dumpi_csmpi.conf

# Locations of dumpi_to_graph stuff
dumpi_to_graph_bin=${anacin_x_root}/submodules/dumpi_to_graph/build/dumpi_to_graph
dumpi_to_graph_config=${anacin_x_root}/submodules/dumpi_to_graph/config/with_callstacks.json

for sample_idx in `seq -f "%04g" ${sample_idx_low} ${sample_idx_high}`;
do
    # Make the directory that will hold this execution's trace files, event 
    # graph, and any other derived data (e.g., event graph slices) specific to 
    # this execution.
    sample_dir="${results_root_dir}/${sample_idx}/"
    mkdir -p ${sample_dir}
    cd ${sample_dir}
                
    # Generate CSMPI configuration
    csmpi_dir=${sample_dir}/csmpi/
    csmpi_config=${sample_dir}/csmpi_config.json
    ${gen_csmpi_config_script} -o ${csmpi_config} -f ${csmpi_mcb_functions} -d ${csmpi_dir} 
    
    # Trace the execution
    trace_job_stdout=$(sbatch -N${n_nodes} ${trace_job_script} ${mcb_executable} ${pnmpi_lib} ${pnmpi_config} ${pnmpi_patched_libs_dir} ${csmpi_config} ${n_nodes} ${n_procs} ${n_procs_per_node} ${n_mpi_tasks_x} ${n_mpi_tasks_y})
    trace_job_id=$(echo ${trace_job_stdout} | sed 's/[^0-9]*//g')

    # Build the event graph representing the execution
    #build_graph_stdout=$(sbatch -N1 --dependency:afterok=${trace_job_id} ${build_graph_job_script} ${sample_dir} ${dumpi_to_graph_executable} ${dumpi_to_graph_cfg})
done


