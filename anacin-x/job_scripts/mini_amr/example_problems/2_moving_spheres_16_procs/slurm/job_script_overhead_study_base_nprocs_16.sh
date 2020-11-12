#!/usr/bin/env bash

#SBATCH -o mini_amr_%j.out
#SBATCH -e mini_amr_%j.err
#SBATCH -t 12:00:00

mini_amr_bin=$1

# Max blocks should be increased if n_refine_levels is increased
# n_refine_levels = 4 and max_blocks = 4000 works 

system=$(hostname | sed 's/[0-9]*//g')

anacin_x_root=$HOME/ANACIN-X/
pnmpi=${anacin_x_root}/submodules/PnMPI/build_${system}/lib/libpnmpi.so
pnmpi_lib_path=${anacin_x_root}/anacin-x/pnmpi/patched_libs_${system}/
pnmpi_conf=${anacin_x_root}/anacin-x/pnmpi/configs/timer.conf

LD_PRELOAD=${pnmpi} PNMPI_LIB_PATH=${pnmpi_lib_path} PNMPI_CONF=${pnmpi_conf} srun -N1 -n16 ${mini_amr_bin} \
    --num_refine 4 \
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
    --num_tsteps 100 \
    --checksum_freq 4 \
    --stages_per_ts 16 \
    --uniform_refine 0 \
    --lb_opt 1 
