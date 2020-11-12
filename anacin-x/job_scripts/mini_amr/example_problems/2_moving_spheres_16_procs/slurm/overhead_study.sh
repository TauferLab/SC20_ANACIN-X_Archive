#!/usr/bin/env bash

# Set number of trials to run per config
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
    results_root="/p/lscratchh/chapp1/mini_amr/overhead_study/system_${system}/"
fi

job_scripts_root=${anacin_x_root}/anacin-x/job_scripts/mini_amr/example_problems/2_moving_spheres_16_procs/slurm/

# miniAMR 
app=${anacin_x_root}/apps/miniAMR/build_${system}_barrier_scheme_1/ma.x

gen_csmpi_config=${anacin_x_root}/submodules/csmpi/config/generate_config.py
csmpi_mini_amr_functions=${anacin_x_root}/submodules/csmpi/config/mpi_function_subsets/mini_amr.json

#scales=(16 64 512)
#scales=(64 512)
#scales=(2048)
scales=(1024)
#configs=("base" "dumpi" "dumpi_csmpi")
#configs=("dumpi" "dumpi_csmpi")
#configs=("base")
#configs=("base" "dumpi")
#configs=("dumpi")
configs=("dumpi_csmpi")

for n_procs in ${scales[@]};
do
    job_script_base=${job_scripts_root}/job_script_overhead_study_base_nprocs_${n_procs}.sh
    job_script_dumpi=${job_scripts_root}/job_script_overhead_study_dumpi_nprocs_${n_procs}.sh
    job_script_dumpi_csmpi=${job_scripts_root}/job_script_overhead_study_dumpi_csmpi_nprocs_${n_procs}.sh
    n_nodes=$(echo "(${n_procs} + ${n_procs_per_node} - 1)/${n_procs_per_node}" | bc)
    for cfg in ${configs[@]};
    do
        runs_root="${results_root}/nprocs_${n_procs}/${cfg}/"
        if [ ${cfg} == "base" ]; then
            for run_idx in `seq -f "%03g" ${run_idx_low} ${run_idx_high}`;
            do
                run_dir="${runs_root}/run_${run_idx}/"
                mkdir -p ${run_dir}
                cd ${run_dir}
                sbatch -N${n_nodes} ${job_script_base} ${app}
            done
        elif [ ${cfg} == "dumpi" ]; then
            for run_idx in `seq -f "%03g" ${run_idx_low} ${run_idx_high}`;
            do
                run_dir="${runs_root}/run_${run_idx}/"
                mkdir -p ${run_dir}
                cd ${run_dir}
                sbatch -N${n_nodes} ${job_script_dumpi} ${app}
            done
        elif [ ${cfg} == "dumpi_csmpi" ]; then
            for run_idx in `seq -f "%03g" ${run_idx_low} ${run_idx_high}`;
            do
                run_dir="${runs_root}/run_${run_idx}/"
                mkdir -p ${run_dir}
                cd ${run_dir}
                # Generate CSMPI configuration
                csmpi_dir=${run_dir}/csmpi/
                csmpi_config=${run_dir}/csmpi_config.json
                ${gen_csmpi_config} -o ${csmpi_config} -f ${csmpi_mini_amr_functions} -d ${csmpi_dir} 
                sbatch -N${n_nodes} ${job_script_dumpi_csmpi} ${app} ${csmpi_config}
            done
        fi
    done
done
