#!/bin/bash -l
#SBATCH -N NNODE
#SBATCH -p QUEUE
#ENABLEQOSBATCH --qos=premium
#SBATCH -A m2621
#SBATCH -t QTIME
#SBATCH -C haswell
#SBATCH -L SCRATCH # needs the parallel file system
#SBATCH -J APP_NNODEnode
#SBATCH -o o%j.APP_NNODEnode
#SBATCH -e o%j.APP_NNODEnode

echo "====Start===="
date

if [[ "$PE_ENV" != "GNU" ]]; then
    module swap PrgEnv-intel PrgEnv-gnu 
fi

let NPROC=NNODE*32
CDIR=${SCRATCH}/hdf5_data/MYCASE
CURDIR=$(pwd)

RUN_CMD="srun -N NNODE -n $NPROC"
REPEAT=REPEATTIME

EXEC1=EXEPATH1
EXEC2=EXEPATH2

set_stripe_nersc_recommend() {
    # rm -rf $CDIR
    mkdir -p $CDIR

    local aggr=$1
    local unit=$2
    local nproc=$3
    local nblk=$4

    let total_size=aggr*nproc*nblk
    if [[ "$unit" == "k" ]]; then
        lfs setstripe -c 1 -S 1m $CDIR
        echo "default stripping"
    elif [[ "$unit" == "m" ]]; then
        if [[ $total_size -gt 102400 ]]; then
            stripe_large $CDIR
            echo "stripe_large"
        elif [[ $total_size -gt 10240 ]]; then
            stripe_medium $CDIR
            echo "stripe_medium"
        elif [[ $total_size -gt 1024 ]]; then
            stripe_small $CDIR
            echo "stripe_small"
        else
            echo "default stripping"
        fi

    elif [[ "$unit" == "g" ]]; then
        if [[ $total_size -gt 100 ]]; then
            stripe_large $CDIR
            echo "stripe_large"
        elif [[ $total_size -gt 10 ]]; then
            stripe_medium $CDIR
            echo "stripe_medium"
        elif [[ $total_size -gt 1 ]]; then
            stripe_small $CDIR
            echo "stripe_small"
        else
            echo "default stripping"
        fi
    else
        echo "Unrecognized unit $unit"
    fi
}

set_stripe_opt() {
    # rm -rf $CDIR
    mkdir -p $CDIR

    local aggr=$1
    local unit=$2
    local nproc=$3
    local nblk=$4

    let per_core_size=aggr*nblk

    if [[ "$unit" == "k" ]]; then
        lfs setstripe -c 128 -S 1m $CDIR
        echo "stripe count 128, size 1m"
    elif [[ "$unit" == "m" ]]; then
        if [[ $per_core_size -gt 16 ]]; then
            lfs setstripe -c 128 -S 16m $CDIR
            echo "stripe count 128, size 16m"
        else
            lfs setstripe -c 128 -S 1m $CDIR
            echo "stripe count 128, size 1m"
        fi
    elif [[ "$unit" == "g" ]]; then
        lfs setstripe -c 128 -S 16m $CDIR
        echo "stripe count 128, size 16m"
    else
        echo "Unrecognized unit $unit"
    fi
}


for (( i = 0; i < REPEAT; i++ )); do
    CDIR=${SCRATCH}/hdf5_data/MYCASE/d_HDF5_d_stripe
    echo "HDF5 default with NERSC recommend stripe setting"
    set_stripe_nersc_recommend BLKSIZE "m" $NPROC NBLK
    lfs getstripe $CDIR | head -n 2
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
    echo "HDF5 optimized with NERSC recommend stripe setting"
    set_stripe_nersc_recommend BLKSIZE "m" $NPROC NBLK
    lfs getstripe $CDIR | head -n 2
    cd $CDIR
    #AMREX_MULTIif [[ ! -d ./grids ]]; then
    #AMREX_MULTI    ln -s $CURDIR/../../grids ./grids
    #AMREX_MULTIfi
    INPUT2="ARGV2"
    run="$RUN_CMD $EXEC2 $INPUT2"
    echo $run
    $run

    sleep 5

    CDIR=${SCRATCH}/hdf5_data/MYCASE/m_HDF5_m_stripe
    echo "HDF5 optimized with optimized stripe setting"
    set_stripe_opt BLKSIZE "m" $NPROC NBLK
    lfs getstripe $CDIR | head -n 2
    cd $CDIR
    #AMREX_MULTIif [[ ! -d ./grids ]]; then
    #AMREX_MULTI    ln -s $CURDIR/../../grids ./grids
    #AMREX_MULTIfi
    INPUT3="ARGV3"
    run="$RUN_CMD $EXEC2 $INPUT3"
    echo $run
    $run

    sleep 5

done

date
echo "====Done===="
