#!/usr/bin/env bash

#SBATCH -o mini_amr_rempi_%j.out
#SBATCH -e mini_amr_rempi_%j.err
#SBATCH -t 12:00:00

mini_amr_bin="$HOME/ANACIN-X/apps/miniAMR/build_catalyst_barrier_scheme_1/ma.x"
n_refine_level=4
lb_opt=1
n_time_steps=10

# Max blocks should be increased if n_refine_levels is increased
# n_refine_levels = 4 and max_blocks = 4000 works 

system=$(hostname | sed 's/[0-9]*//g')

rempi_lib="$HOME/ReMPI/build_catalyst/lib/librempix.so"
rempi_mode=0 # Record
rempi_dir="/p/lscratchh/chapp1/rempi/"
rempi_encode=1 # CDC
rempi_test_id=0 # MF identification

anacin_x_root=$HOME/ANACIN-X/
LD_PRELOAD=${rempi_lib} REMPI_MODE=${rempi_mode} REMPI_DIR=${rempi_dir} REMPI_ENCODE=${rempi_encode} REMPI_TEST_ID=${rempi_test_id} srun -N1 -n16 ${mini_amr_bin} \
    --num_refine ${n_refine_level} \
    --max_blocks 8000 \
    --init_x 1 \
    --init_y 1 \
    --init_z 1 \
    --npx 4 \
    --npy 2 \
    --npz 2 \
    --nx 8 \
    --ny 8 \
    --nz 8 \
    --num_objects 2 \
    --object 2 0 -1.10 -1.10 -1.10 0.030 0.030 0.030 1.5 1.5 1.5 0.0 0.0 0.0 \
    --object 2 0 0.5 0.5 1.76 0.0 0.0 -0.025 0.75 0.75 0.75 0.0 0.0 0.0 \
    --num_tsteps ${n_time_steps} \
    --checksum_freq 4 \
    --stages_per_ts 16 \
    --uniform_refine 0 \
    --lb_opt ${lb_opt} \
    --log
