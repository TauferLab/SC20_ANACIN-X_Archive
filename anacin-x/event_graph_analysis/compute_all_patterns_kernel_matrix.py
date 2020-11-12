#!/usr/bin/env python3

#SBATCH -o compute-graph-kernels-%j.out
#SBATCH -e compute-graph-kernels-%j.err
#SBATCH -t 12:00:00

import argparse
import pprint
import time
import re
import os
import glob
import json
import numpy as np
import pickle as pkl
import psutil

# Import igraph bindings
import igraph

# Import Borgwardt Lab graph kernel implementations
import graphkernels
import graphkernels.kernels as gk

# Suppress sklearn deprecation warning from grakel
import warnings
warnings.simplefilter(action='ignore', category=FutureWarning)

# Import generic GraKeL graph kernel interface
import grakel
from grakel import GraphKernel

# Import event graph utilities
import sys
sys.path.append(".")
sys.path.append("..")
from event_graph_analysis.utilities import read_graph, read_run_params, timer
from event_graph_analysis.graph_kernel_utils import preprocess


class graph_loader(object):
    def __init__(self, base_dir, run_dir_depth, max_run_idx):
        self._base_dir = base_dir
        self._run_dir_depth = run_dir_depth
        self._max_run_idx = max_run_idx
        self._eg_ext = "graphml"
        self._run_dir_to_data = self._load_graphs()

    def _load_graphs(self):
        glob_path = self._base_dir
        for _ in range(self._run_dir_depth):
            glob_path += "/*/"
        glob_path += "/run_*"
        run_dirs = sorted(glob.glob(glob_path), key=lambda x: self._run_dir_to_key(x)) 
        if self._max_run_idx is not None:
            run_dirs = self._select_runs(run_dirs, self._max_run_idx)
        run_dir_to_data = {rd:{"event_graph":read_graph(rd+"/event_graph." + self._eg_ext),
                               "run_params":read_run_params(rd+"/run_params.json")} for rd in run_dirs}
        return run_dir_to_data

    def _run_dir_to_key(self, rd):
        parts = rd.split("/")
        run_idx_part = parts[-1] 
        ndp_part = parts[-2]
        run_idx = int(re.sub(r"[^0-9]", "", run_idx_part))
        ndp = int(re.sub(r"[^0-9]", "", ndp_part))
        return (ndp, run_idx)

    def _select_runs(self, run_dirs, max_run_idx):
        selected_runs = []
        for rd in run_dirs:
            run_idx = int(re.sub("[^0-9]", "", os.path.basename(rd)))
            if run_idx <= max_run_idx:
                selected_runs.append(rd)
        return selected_runs

    def get_run_dir_to_data(self):
        return self._run_dir_to_data





class graph_kernel_manager(object):
    def __init__(self, graphs, kernels,
                 labeling_options_path=None,
                 kernel_matrices_cache_path=None, kernel_matrices_output_path=None,
                 wl_iters=None, 
                 graphlet_sampling_dims=None, 
                 graphlet_sampling_counts=None
                ):

        # The graphs we will be computing graph kernel similarities of
        self._graphs = graphs

        # A mapping between kernel/parameter keys and kernel matrices
        self._kernel_matrices = {}

        # List of graph kernels to compute similarity matrices for
        self._kernels = kernels

        # Default graph kernel implementation library
        self._default_impl = "grakel"

        # Location of pre-computed kernel matrices 
        self._kernel_matrices_cache_path = kernel_matrices_cache_path

        # Location to write kernel matrices out to
        self._kernel_matrices_output_path = kernel_matrices_output_path

        # Kernel-specific configuration parameters
        # These are only used if the 
        self._wl_iters = wl_iters
        self._graphlet_sampling_dims = graphlet_sampling_dims
        self._graphlet_sampling_counts = graphlet_sampling_counts

        # Default locations of configs
        self._default_base_kernels_path = "config/graph_kernels/grakel_base_kernels.json"
        self._default_graph_attributes_path = "config/graph_kernels/event_graph_attributes.json"
        self._default_labeling_options_path = "config/graph_kernels/labeling_options.json"

        # Load base kernel definitions
        self._base_kernel_defs = self._load_base_kernel_defs(self._default_base_kernels_path)

        # Load graph labeling options
        if labeling_options_path is None:
            self._labeling_options = self._load_labeling_options(self._default_labeling_options_path)
        else:
            self._labeling_options = self._load_labeling_options(labeling_options_path)
        
    

    
    
    def _load_base_kernel_defs(self, base_kernels_path):
        """
        Load GraKeL base graph kernel definitions/parameters from config file
        """
        with open(base_kernels_path, "r") as infile:
            base_kernels = json.load(infile)
        return base_kernels


    def _load_labeling_options(self, labeling_options_path):
        """
        Load graph labeling options from config file
        """
        with open(labeling_options_path, "r") as infile:
            labeling_options = json.load(infile)
        return labeling_options
    

    def compute_kernels(self):

        # Load preexisting kernel matrices, if provided
        if self._kernel_matrices_cache_path is not None and os.path.exists(self._kernel_matrices_cache_path):
            with open(self._kernel_matrices_cache_path, "rb") as infile:
                self._kernel_matrices = pkl.load(infile)

        # Preprocess graphs as needed based on requested kernels and labelings
        labeling_to_graphs = preprocess(self._graphs, self._base_kernel_defs, self._kernels, self._labeling_options)
        
        # Loop over kernels
        for k_id, k_def in self._base_kernel_defs.items():

            # Check if we're computing the current kernel
            if k_id in self._kernels:
                
                # Handle Vertex Histogram case
                if k_id == "vertex_histogram":
                    self._compute_vertex_histogram_kernel(labeling_to_graphs, k_def["params"])

                # Handle WLST case
                elif k_id == "subtree_wl":
                    self._compute_wlst_kernel(labeling_to_graphs, k_def["params"])
                
                # Handle graphlet sampling case
                elif k_id == "graphlet_sampling":
                    self._compute_graphlet_sampling_kernel(labeling_to_graphs, k_def["params"]) 
                
                # Handle unlabeled shortest path case
                elif k_id == "shortest_path":
                    self._compute_unlabeled_shortest_path_kernel(labeling_to_graphs, k_def["params"])

                # Handle unlabeled random walk case
                elif k_id == "random_walk":
                    self._compute_unlabeled_random_walk_kernel(labeling_to_graphs, k_def["params"])
                
                # Handle labeled shortest path case
                elif k_id == "shortest_path_labeled":
                    self._compute_labeled_shortest_path_kernel(labeling_to_graphs, k_def["params"])

                # Handle labeled random walk case
                elif k_id == "random_walk_labeled":
                    self._compute_labeled_random_walk_kernel(labeling_to_graphs, k_def["params"])

                # Handle neighborhood hash case
                elif k_id == "neighborhood_hash":
                    self._compute_neighborhood_hash_kernel(labeling_to_graphs, k_def["params"])
                
                # Handle odd-sth case
                elif k_id == "odd_sth":
                    self._compute_odd_sth_kernel(labeling_to_graphs, k_def["params"])

        
        # Write kernel matrices to file
        with open(self._kernel_matrices_output_path, "wb") as outfile:
            pkl.dump(self._kernel_matrices, outfile, 0)

    @timer
    def _compute_kernel_matrix_grakel(self, event_graphs, kernel_params):
        """
        Generic wrapper for GraKeL's graph kernel interface
        """
        kernel = GraphKernel(kernel_params)
        kernel_mat = kernel.fit_transform(event_graphs)
        return kernel_mat


    def _compute_vertex_histogram_kernel(self, labeling_to_graphs, k_params):
        """
        Compute vertex histogram kernel using specified implementation
        """
        for lab,graphs in labeling_to_graphs.items():
            if lab != "unlabeled":
                vertex_label = lab[0]
                key = (k_params["name"], vertex_label)
                if key in self._kernel_matrices:
                    print("Kernel: {} already computed".format(key))
                else:
                    print("Computing kernel: {}".format(key))
                    mat = self._compute_kernel_matrix_grakel(graphs,k_params)
                    self._kernel_matrices[key] = mat


    def _compute_unlabeled_shortest_path_kernel(self, labeling_to_graphs, k_params):
        graphs = labeling_to_graphs["unlabeled"]
        key = (k_params["name"])
        if key in self._kernel_matrices:
            print("Kernel: {} already computed".format(key))
        else:
            print("Computing kernel: {}".format(key))
            mat = self._compute_kernel_matrix_grakel(graphs,k_params)
            self._kernel_matrices[key] = mat


    def _compute_unlabeled_random_walk_kernel(self, labeling_to_graphs, k_params):
        graphs = labeling_to_graphs["unlabeled"]
        key = (k_params["name"])
        if key in self._kernel_matrices:
            print("Kernel: {} already computed".format(key))
        else:
            print("Computing kernel: {}".format(key))
            mat = self._compute_kernel_matrix_grakel(graphs,k_params)
            self._kernel_matrices[key] = mat
        

    def _compute_labeled_shortest_path_kernel(self, labeling_to_graphs, k_params):
        for lab,graphs in labeling_to_graphs.items():
            if lab != "unlabeled":
                vertex_label = lab[0]
                key = (k_params["name"], vertex_label)
                if key in self._kernel_matrices:
                    print("Kernel: {} already computed".format(key))
                else:
                    print("Computing kernel: {}".format(key))
                    mat = self._compute_kernel_matrix_grakel(graphs,k_params)
                    self._kernel_matrices[key] = mat
        

    def _compute_labeled_random_walk_kernel(self, labeling_to_graphs, k_params):
        for lab,graphs in labeling_to_graphs.items():
            if lab != "unlabeled":
                vertex_label = lab[0]
                key = (k_params["name"], vertex_label)
                if key in self._kernel_matrices:
                    print("Kernel: {} already computed".format(key))
                else:
                    print("Computing kernel: {}".format(key))
                    mat = self._compute_kernel_matrix_grakel(graphs,k_params)
                    self._kernel_matrices[key] = mat


    def _compute_neighborhood_hash_kernel(self, labeling_to_graphs, k_params):
        for lab,graphs in labeling_to_graphs.items():
            if lab != "unlabeled":
                vertex_label = lab[0]
                key = (k_params["name"], vertex_label)
                if key in self._kernel_matrices:
                    print("Kernel: {} already computed".format(key))
                else:
                    print("Computing kernel: {}".format(key))
                    mat = self._compute_kernel_matrix_grakel(graphs,k_params)
                    self._kernel_matrices[key] = mat


    def _compute_odd_sth_kernel(self, labeling_to_graphs, k_params):
        for lab,graphs in labeling_to_graphs.items():
            if lab != "unlabeled":
                vertex_label = lab[0]
                key = (k_params["name"], vertex_label)
                if key in self._kernel_matrices:
                    print("Kernel: {} already computed".format(key))
                else:
                    print("Computing kernel: {}".format(key))
                    mat = self._compute_kernel_matrix_grakel(graphs,k_params)
                    self._kernel_matrices[key] = mat
        

    def _compute_wlst_kernel(self, labeling_to_graphs, k_params):
        for lab,graphs in labeling_to_graphs.items():
            if lab != "unlabeled":
                vertex_label = lab[0]
                for n_iters in self._wl_iters:
                    key = (k_params["name"], vertex_label, n_iters)
                    if key in self._kernel_matrices:
                        print("Kernel: {} already computed".format(key))
                    else:
                        print("Computing kernel: {}".format(key))
                        grakel_params = [{"name" : "weisfeiler_lehman", "n_iter" : n_iters}, 
                                    {"name" : "subtree_wl"}]
                        mat = self._compute_kernel_matrix_grakel(graphs, grakel_params)
                        self._kernel_matrices[key] = mat


    def _compute_graphlet_sampling_kernel(self, labeling_to_graphs, k_params):
        graphs = labeling_to_graphs["unlabeled"]
        for dim in self._graphlet_sampling_dims:
            for count in self._graphlet_sampling_counts:
                key = (k_params["name"], dim, count)
                if key in self._kernel_matrices:
                    print("Kernel: {} already computed".format(key))
                else:
                    print("Computing kernel: {}".format(key))
                    kernel = grakel.GraphletSampling(k=dim, sampling={"n_samples":count})
                    mat = kernel.fit_transform(graphs)
                    self._kernel_matrices[key] = mat




def main(base_dir, 
         run_dir_depth, 
         kernels, 
         labeling_path, 
         max_run_idx, 
         kernel_matrices_cache, 
         kernel_matrices_output, 
         run_params_output_path, 
         wl_iters=None,
         graphlet_sampling_dims=None,
         graphlet_sampling_counts=None
        ):

    loader = graph_loader(base_dir, run_dir_depth, max_run_idx)
    run_dir_to_data = loader.get_run_dir_to_data()

    pprint.pprint(run_dir_to_data)
    exit()

    event_graphs = []
    run_params = []
    print("Loaded runs:")
    for rd,data in run_dir_to_data.items():
        #print("\t{}".format(rd))
        event_graphs.append( data["event_graph"] )
        run_params.append( data["run_params"] )

    with open(run_params_output_path, "wb") as outfile:
        pkl.dump(run_params, outfile, 0)
    
    gk_manager = graph_kernel_manager(event_graphs, 
                                      kernels,
                                      labeling_path, 
                                      kernel_matrices_cache, 
                                      kernel_matrices_output, 
                                      wl_iters,
                                      graphlet_sampling_dims,
                                      graphlet_sampling_counts
                                     )
    print("Computing graph kernels")
    gk_manager.compute_kernels()




if __name__ == "__main__":
    paths = []
    paths += glob.glob("/p/lscratchh/chapp1/thesis_results/comm_patterns/message_race_iters_10/system_catalyst/n_procs_21/proc_placement_pack/msg_size_1/*/run*/")
    paths += glob.glob("/p/lscratchh/chapp1/thesis_results/comm_patterns/amg2013/system_catalyst/n_procs_21/proc_placement_pack/msg_size_1/*/run*/")
    paths += glob.glob("/p/lscratchh/chapp1/thesis_results/comm_patterns/mcb_grid/system_catalyst/n_procs_21/proc_placement_pack/*/run*/")
    paths += glob.glob("/p/lscratchh/chapp1/thesis_results/comm_patterns/unstructured_mesh/system_quartz/n_procs_64/proc_placement_pack/msg_size_1/*/*/run*/")
    print(len(paths))
    
    n = len(paths)
    start = time.time()
    graphs = []
    run_params = []
    proc = psutil.Process(os.getpid())
    for i,p in enumerate(sorted(paths)):
        #graphs.append(read_graph(p+"/event_graph.graphml"))
        run_params.append(read_run_params(p+"/run_params.json"))
        #print("Loaded graph {}/{}".format(i,n))
        #print("GB used: {}".format(proc.memory_info().rss / 1e9))
    #print("Time to load all graphs: {}".format(time.time() - start))
    
    with open("/p/lscratchh/chapp1/thesis_results/comm_patterns/run_params_all_patterns.pkl", "wb") as outfile:
        pkl.dump(run_params, outfile, 0)

    kernels = ["subtree_wl"]
    wl_iters = [2, 4, 8, 16]
    #gk_manager = graph_kernel_manager(graphs, kernels, "./config/graph_kernels/labeling_options.json", None, "/p/lscratchh/chapp1/thesis_results/comm_patterns/kernel_matrices_all_patterns_2.pkl", wl_iters, None, None)
    #gk_manager.compute_kernels()

