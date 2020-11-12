#!/usr/bin/env bash

#SBATCH -o backup_mini_amr_data.out
#SBATCH -e backup_mini_amr_data.err
#SBATCH -t 12:00:00


cp -R "/p/lscratchh/chapp1/mini_amr/debug/system_catalyst/nprocs_16_2_moving_spheres" "/usr/workspace/chapp1/thesis_results/mini_amr/"
