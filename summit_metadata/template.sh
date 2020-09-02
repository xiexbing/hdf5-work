#!/bin/bash -l
#BSUB -P stf008 
#BSUB -W 2:00
#BSUB -nnodes NNODE
##BSUB -w ended(PREVJOBID)
# #BSUB -alloc_flags gpumps
#BSUB -J IOR_NNODEnode
#BSUB -o o%J.ior_NNODEnode
#BSUB -e o%J.ior_NNODEnode

#module load hdf5/1.10.3

let NPROC=NNODE
CDIR=ior_data
EXEC=/gpfs/alpine/stf008/scratch/bing/ior/src/ior
LD_LIBRARY_PATH=/gpfs/alpine/csc300/world-shared/hdf5-1.10.6/hdf5/lib:$LD_LIBRARY_PATH
EXEC_C=/gpfs/alpine/stf008/scratch/bing/ior_rank/src/ior

export MPICH_MPIIO_STATS=1
export MPICH_MPIIO_HINTS_DISPLAY=1
export MPICH_MPIIO_TIMERS=1
export DARSHAN_DISABLE_SHARED_REDUCTION=1
export DXT_ENABLE_IO_TRACE=4


sizes="16k 256k 1m 16m 64m"

datasets="2 8 32 128"

cols="0 1"
#cols="--hdf5.collectiveMetadata"

defs="0 1"
#defs="--hdf5.deferFlush $e"

mblocks="0 1"
#mblocks="--hdf5.metaBlock $e"

ior(){
    local i=$1
    local size=$2
    local dataset=$3
    local wcol=$4
    local wblock=$5

    export HDF5_NUM_DATASET=$dataset

    mkdir -p $CDIR

    if [[ $wcol == "1" ]]; then
        col="--hdf5.collectiveMetadata"
    else
        col="" 
    fi

    if [[ $wblock == "1" ]]; then
        mblock="--hdf5.metaBlock"
    else
        mblock="" 
    fi

    defer_flush(){
        local wdef=$1

        if [[ $wdef == "1" ]]; then
            def="--hdf5.deferFlush"
        else
            def="" 
        fi

        #flush data in data transfer 
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b $size -t $size -i 1 -v -v -v -k -a HDF5 -J 16m -e -w -o $CDIR/${NPROC}p_${i}_${wdef}_${dataset}_${size}_f&>>meta_${size}_${dataset}_${wdef}_${wcol}_${wblock}_f $def $col $mblock 
    }
    for wdef in $defs; do
        defer_flush $wdef
    done 

    #read
    jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b $size -t $size -i 1 -v -v -v -k -a HDF5 -J 16m  -r -C -o $CDIR/${NPROC}p_${i}_${wdef}_${dataset}_${size}_f &>>meta_${size}_${dataset}_${wcol}_${wblock}_r $col $mblock 

    rm -rf $CDIR

}
for i in $(seq 1 1 5); do
    for size in $sizes; do
        for dataset in $datasets; do
            for wcol in $cols; do
                for wblock in $mblocks; do
                    ior $i $size $dataset $wcol $wblock
                done
            done
        done
    done
done
