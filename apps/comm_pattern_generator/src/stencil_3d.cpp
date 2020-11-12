#include "stencil_3d.hpp"

#include <mpi.h>
#include <cstdio>
#include <cstdlib>
#include <vector>

#include "debug.hpp"


void comm_pattern_stencil_3d( int iter, int n_sub_iters, double nd_fraction, int msg_size,
                              int n_procs_x, int n_procs_y, int n_procs_z,
                              int n_grid_cells_x, int n_grid_cells_y, int n_grid_cells_z )
{
  int n_vars = msg_size;

  // Define some convenience vars
  auto xy_plane_area = n_grid_cells_x * n_grid_cells_y;
  auto xz_plane_area = n_grid_cells_x * n_grid_cells_z;
  auto yz_plane_area = n_grid_cells_y * n_grid_cells_z;
  auto var_payload_size = n_vars * sizeof(char);
  auto left_right_block_size = xy_plane_area * var_payload_size; 
  auto up_down_block_size    = xz_plane_area * var_payload_size;
  auto front_back_block_size = yz_plane_area * var_payload_size;

  // Define data to move along the left-right axis
  char* left_block_out  = (char*) malloc( left_right_block_size );
  char* left_block_in   = (char*) malloc( left_right_block_size );
  char* right_block_out = (char*) malloc( left_right_block_size );
  char* right_block_in  = (char*) malloc( left_right_block_size );
  
  // Define data to move along the up-down axis
  char* up_block_out   = (char*) malloc( up_down_block_size );
  char* up_block_in    = (char*) malloc( up_down_block_size );
  char* down_block_out = (char*) malloc( up_down_block_size );
  char* down_block_in  = (char*) malloc( up_down_block_size );
  
  // Define data to move along the front-back axis
  char* front_block_out = (char*) malloc( front_back_block_size );
  char* front_block_in  = (char*) malloc( front_back_block_size );
  char* back_block_out  = (char*) malloc( front_back_block_size );
  char* back_block_in   = (char*) malloc( front_back_block_size );

  // Allocate requests
  int n_dimensions = 3;
  int n_directions = 2;
  int n_requests = n_dimensions * n_directions * n_sub_iters;
  MPI_Request* recv_reqs = (MPI_Request*) malloc( n_requests * sizeof(MPI_Request) )
  MPI_Request* send_reqs = (MPI_Request*) malloc( n_requests * sizeof(MPI_Request) )

  // Determine which subiters 

  for ( int i=0; i<n_sub_iters; ++i ) {
     
  }
}
