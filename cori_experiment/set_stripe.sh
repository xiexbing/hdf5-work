#!/bin/bash -l
#SBATCH -N NNODE
#SBATCH -p regular
# #SBATCH --qos=premium
# #SBATCH -p debug
#SBATCH -A m1248
#SBATCH -t 03:00:00
#SBATCH -C haswell
#SBATCH -L SCRATCH # needs the parallel file system
#SBATCH -J IOR_NNODEnode
#SBATCH -o o%j.ior_NNODEnode
#SBATCH -e o%j.ior_NNODEnode

module swap PrgEnv-gnu PrgEnv-intel

let NPROC=NNODE
CDIR=${SCRATCH}/ior_data
EXEC=${HOME}/hdf5-work/ior/src/ior

# export LD_LIBRARY_PATH=${HOME}/cori/hdf5-1.10.6/build/hdf5/lib:$LD_LIBRARY_PATH
export MPICH_MPIIO_STATS=1
export MPICH_MPIIO_HINTS_DISPLAY=1
export MPICH_MPIIO_TIMERS=1
export DARSHAN_DISABLE_SHARED_REDUCTION=1
export DXT_ENABLE_IO_TRACE=4

    mkdir -p $CDIR
    lfs setstripe -c 248 -S 16m $CDIR

    rm -rf $CDIR
#for the hdf5 setting with specific alignment value, the api is HDF5+alignment_setting_value, for the runs with hdf5 setting we perform the ior with no collective i/o for hdf5 metadata, and with collective i/o for hdf5 metadata.
apis="POSIX MPIIO HDF5 HDF51m HDF54m HDF516m HDF564m HDF5256m"

sizes="1 16 256"
units="k m"

sizeg="1"
unitg="g"

run_cmd="srun -N NNODE -n $NPROC"

set_stripe_nersc_recommand() {
    rm -rf $CDIR
    mkdir $CDIR

    local aggr=$1
    local unit=$2
    local nproc=$3
    local nblk=$4

    let total_size=aggr*nproc*nblk
    if [[ $unit == "k"]]; then
        # use default striping for KB block size
        stripe_cmd=""
    elif [[ $unit == "m"]]; then
        if [[ $total_size -gt 1024 ]]; then
            stripe_small $CDIR
        fi
        if [[ $total_size -gt 10240 ]]; then
            stripe_medium $CDIR
        fi
        if [[ $total_size -gt 102400 ]]; then
            stripe_large $CDIR
        fi

    elif [[ $unit == "g"]]; then
        if [[ $total_size -gt 1 ]]; then
            stripe_small $CDIR
        fi
        if [[ $total_size -gt 10 ]]; then
            stripe_medium $CDIR
        fi
        if [[ $total_size -gt 100 ]]; then
            stripe_large $CDIR
        fi
    fi
}

set_stripe_opt() {
    rm -rf $CDIR
    mkdir $CDIR

    local aggr=$1
    local unit=$2
    local nproc=$3
    local nblk=$4

    let per_core_size=aggr*nblk

    if [[ $unit == "k"]]; then
        # use default striping for KB block size
        lfs setstripe -c 128 -S 1m $CDIR
    elif [[ $unit == "m"]]; then
        if [[ $per_core_size -gt 16 ]]; then
            lfs setstripe -c 128 -S 16m $CDIR
        else
            lfs setstripe -c 128 -S 1m $CDIR
        fi
    elif [[ $unit == "g"]]; then
        lfs setstripe -c 128 -S 16m $CDIR
    fi
}



