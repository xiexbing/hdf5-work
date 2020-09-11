#!/bin/bash -l
#SBATCH -N 2
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

CDIR=${SCRATCH}/ior_data
d_ior=${HOME}/hdf5-work/ior/src/ior
m_ior=${HOME}/hdf5-work/ior.mod/src/ior
configurations="d_lustre_d_hdf5 d_lustre_m_hdf5 m_lustre_m_hdf5"

export MPICH_MPIIO_STATS=1
export MPICH_MPIIO_HINTS_DISPLAY=1
export MPICH_MPIIO_TIMERS=1
export DARSHAN_DISABLE_SHARED_REDUCTION=1
export DXT_ENABLE_IO_TRACE=4

mkdir -p result

per(){
    local i=$1
    local group=$2
    local size=$3
    local core=$4
    local dataset=$5

    export HDF5_NUM_DATASET=$dataset

    mkdir -p $CDIR

    write(){
        local wior=$1
   
       #assign the version of ior
        if [[ $wior == *"d_hdf5"* ]]; then
            ior=$d_ior
        elif [[ $wior == *"m_hdf5"* ]]; then
            ior=$m_ior
        fi

        #assign the nersc recommended striping 
        if [[ $wior == *"d_lustre"* ]]; then
            if [[ $group == "g1" ]]; then
                lfs setstripe -c 1 -S 1m $CDIR
            elif [[ $group == "g2" ]]; then
                stripe_small $CDIR
            elif [[ $group == "g3" ]]; then
                stripe_medium $CDIR
            elif [[ $group == "g4" ]]; then
                stripe_large $CDIR
            fi
        elif [[ $wior == *"m_lustre"* ]]; then
               lfs setstripe -c 128 -S 16m $CDIR
        fi
 
        #assign alignment
        if [[ $wior == *"d_hdf5"* ]]; then
            align=2k
        elif [[ $wior == *"m_hdf5"* ]]; then
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
   
        #assign the version of ior
        if [[ $rior == *"d_hdf5"* ]]; then
            ior=$d_ior
        elif [[ $rior == *"m_hdf5"* ]]; then
            ior=$m_ior
        fi

        #assign alignment
        if [[ $rior == *"d_hdf5"* ]]; then
            align=2k 
        elif [[ $rior == *"m_hdf5"* ]]; then
            align=1m
            if [[ "m" == *"${size}"* ]]; then
                size_value=`echo $size|sed "s/m//"`
                if [[ $size_value -ge 16 ]]; then
                    align=16m
                fi
            fi
        fi




        if [[ $rior == *"m_hdf5"* ]]; then
 
            jsrun -n $NPROC -r 1 -a $core -c $core $ior -b $size -t $size -i 1 -v -v -v -k -a HDF5 -J $align  -r -Z -o $CDIR/${NPROC}p_${size}_${core}_${dataset}_${rior}_f&>>result/${size}_${core}_${dataset}_${rior}_r  --hdf5.collectiveMetadata
        else
            jsrun -n $NPROC -r 1 -a $core -c $core $ior -b $size -t $size -i 1 -v -v -v -k -a HDF5 -J $align  -r -Z -o $CDIR/${NPROC}p_${size}_${core}_${dataset}_${rior}_f&>>result/${size}_${core}_${dataset}_${rior}_r
        fi 
 
    }
    for rior in $configurations; do
        read $rior
    done 
    rm -rf $CDIR
}
