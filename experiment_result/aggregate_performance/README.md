This aggregate_performance directory contains IOR experiment results using POSIX, MPI-IO, and HDF5 for three different access patterns in different sub-directories:

# baseline
This set of IOR experiments write or read 1 block with varying sizes and number of nodes (1 MPI rank per node), indicated by each file name in the following format: 
  baseline_node{i}_{s}_{m}.pdf
where i is the number of nodes, s is the block size (16k to 1g), and m is either f (write) or r (read).

# blocks
This set of experiments write or read multiple blocks with varying sizes and number of nodes (1 MPI rank per node), the file name format is similar as the baseline one, with three series of boxplots (4, 8, 16 blocks) in each file.

# collective
This set of IOR experiments write or read 1 block with varying sizes, number of nodes, and number of MPI ranks per node, the file name format is similar as the baseline one, with three series of boxplots (4, 8, 16 cores per node) in each file.
