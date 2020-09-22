# hdf5-work
# IO Benchmarking Templates on Supercomputers

This repo includes the benchmarking templates for understanding and tuning HDF5 performance on three production supercomputers: summit at ORNL, cori at LBL and theta at ANL. 

ior/ includes the modified source code of IOR, which exeplicitly fsync() I/O writes for POSIX, MPI, and HDF5, with option "-e". And fsync() during file close in default. 

summit_/ include all the IOR templates designed for and runing on summit.

cori_/ include all the IOR templates designed for and running on cori.  

experiment_result/ include all the experiment result plots for various access patterns and APIs.
