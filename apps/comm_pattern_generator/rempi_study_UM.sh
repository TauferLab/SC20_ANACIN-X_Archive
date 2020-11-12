#!/usr/bin/env bash

#SBATCH -o comm_pattern_rempi_%j.out
#SBATCH -e comm_pattern_rempi_%j.err
#SBATCH -t 12:00:00

bin="./build_catalyst/comm_pattern_generator"
config="./config/debug_rempi_UM.json"


base_dir="/p/lscratchh/chapp1/rempi_study/UM/"
mkdir -p ${base_dir}





rempi_lib="$HOME/ReMPI/build_catalyst/lib/librempix.so"
rempi_mode=0 # Record
rempi_dir="/p/lscratchh/chapp1/rempi_debug/UM/"
rempi_encode=4 # CDC
rempi_test_id=0 # MF identification

mkdir -p ${rempi_dir}

anacin_x_root=$HOME/ANACIN-X/
LD_PRELOAD=${rempi_lib} REMPI_MODE=${rempi_mode} REMPI_DIR=${rempi_dir} REMPI_ENCODE=${rempi_encode} REMPI_TEST_ID=${rempi_test_id} srun -N1 -n24 ${bin} ${config}
