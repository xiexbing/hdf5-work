This aggregate_performance directory contains IOR experiment results using POSIX, MPI-IO, and HDF5.

# baseline
This set of IOR experiments write or read 1 block with varying sizes and number of nodes (1 MPI rank per node), indicated by each file name in the following format: 
  baseline_node{i}_{s}_rank{r}_{m}.pdf
where i is the number of nodes, s is the block size (16k to 1g), r is the MPI rank ID, and m is either f (write) or r (read).


