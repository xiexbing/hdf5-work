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
d_ior=/gpfs/alpine/csc300/world-shared/xl_build/ior/src/ior
m_ior=/gpfs/alpine/csc300/world-shared/xl_build/ior.mod/src/ior
configurations="d_hdf5 m_hdf5"

export MPICH_MPIIO_STATS=1
export MPICH_MPIIO_HINTS_DISPLAY=1
export MPICH_MPIIO_TIMERS=1
export DARSHAN_DISABLE_SHARED_REDUCTION=1
export DXT_ENABLE_IO_TRACE=4

mkdir -p result

per(){
    local i=$1
    local size=$2
    local core=$3
    local dataset=$4

    export HDF5_NUM_DATASET=$dataset

    mkdir -p $CDIR

    write(){
        local wior=$1
   
        #assign ior version
        if [[ $wior == "d_hdf5" ]]; then
            ior=$d_ior
        elif [[ $wior == "m_hdf5" ]]; then
            ior=$m_ior
        fi

        #assign align
        if [[ $wior == "d_hdf5" ]]; then
            align=2k
        elif [[ $wior == "m_hdf5" ]]; then
            align=1m
            if [[ "m" == *"${size}"* ]]; then
                size_value=`echo $size|sed "s/m//"`
                if [[ $size_value -ge 16 ]]; then
                    align=16m
                fi
            fi

        fi

        jsrun -n $NPROC -r 1 -a $core -c $core $ior -b $size -t $size -i 1 -v -v -v -k -a HDF5 -J $align -e -w -o $CDIR/${NPROC}p_${size}_${core}_${dataset}_${wior}_f&>>result/${size}_${core}_${dataset}_${wior}_f
    }
    for wior in $configurations; do
        write $wior
    done        

    #read
    read(){
        local rior=$1
        #assign ior
        if [[ $rior == "d_hdf5" ]]; then
            ior=$d_ior
        elif [[ $rior == "m_hdf5" ]]; then
            ior=$m_ior
        fi
        #assign alignment
        if [[ $rior == "d_hdf5" ]]; then
            align=2k
        elif [[ $rior == "m_hdf5" ]]; then
            align=1m
            if [[ "m" == *"${size}"* ]]; then
                size_value=`echo $size|sed "s/m//"`
                if [[ $size_value -ge 16 ]]; then
                    align=16m
                fi
            fi      
        fi

        if [[ $rior == "m_hdf5" ]]; then
            jsrun -n $NPROC -r 1 -a $core -c $core $ior -b $size -t $size -i 1 -v -v -v -k -a HDF5 -J $align  -r -Z -o $CDIR/${NPROC}p_${size}_${core}_${dataset}_${rior}_f&>>result/${size}_${core}_${dataset}_${rior}_r --hdf5.collectiveMetadata
        else
            jsrun -n $NPROC -r 1 -a $core -c $core $ior -b $size -t $size -i 1 -v -v -v -k -a HDF5 -J $align  -r -Z -o $CDIR/${NPROC}p_${size}_${core}_${dataset}_${rior}_f&>>result/${size}_${core}_${dataset}_${rior}_r
        fi
    }
    for rior in $configurations; do
        read $rior
    done 
    rm -rf $CDIR
}
