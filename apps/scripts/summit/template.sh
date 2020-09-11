#!/bin/bash -l
#BSUB -P CSC300
#BSUB -W QTIME
#BSUB -nnodes NNODE
##BSUB -w ended(PREVJOBID)
#BSUB -J APP_NNODEnode
#BSUB -o o%J.APP_NNODEnode
#BSUB -e o%J.APP_NNODEnode

echo "====Start===="
date

ml gcc
export MPICH_MPIIO_STATS=1
export MPICH_MPIIO_HINTS_DISPLAY=1
export MPICH_MPIIO_TIMERS=1
export DARSHAN_DISABLE_SHARED_REDUCTION=1
export DXT_ENABLE_IO_TRACE=4


SCRATCH=/gpfs/alpine/scratch/houjun/csc300/

let NPROC=NNODE*6
CURDIR=$(pwd)

RUN_CMD="jsrun -n $NPROC -r 6 -a 1 -c 1 "
REPEAT=REPEATTIME

EXEC1=EXEPATH1
EXEC2=EXEPATH2

for (( i = 0; i < REPEAT; i++ )); do
    CDIR=${SCRATCH}/hdf5_data/MYCASE/d_HDF5_d_stripe
    echo "HDF5 default"
    mkdir -p $CDIR
    cd $CDIR
    #AMREX_MULTIif [[ ! -d ./grids ]]; then
    #AMREX_MULTI    ln -s $CURDIR/../../grids ./grids
    #AMREX_MULTIfi

    INPUT1="ARGV1"
    run="$RUN_CMD $EXEC1 $INPUT1"
    echo $run
    $run

    sleep 5

    CDIR=${SCRATCH}/hdf5_data/MYCASE/m_HDF5_d_stripe
    echo "HDF5 optimized"
    mkdir -p $CDIR
    cd $CDIR
    #AMREX_MULTIif [[ ! -d ./grids ]]; then
    #AMREX_MULTI    ln -s $CURDIR/../../grids ./grids
    #AMREX_MULTIfi
    INPUT2="ARGV2"
    run="$RUN_CMD $EXEC2 $INPUT2"
    echo $run
    $run

    sleep 5

done

date
echo "====Done===="
