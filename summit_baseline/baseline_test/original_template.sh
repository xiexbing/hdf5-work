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


#for the hdf5 setting with specific alignment value, the api is HDF5+alignment_setting_value, for the runs with hdf5 setting we perform the ior with no collective i/o for hdf5 metadata, and with collective i/o for hdf5 metadata.
apis="POSIX MPIIO HDF5 HDF51m HDF54m HDF516m HDF564m HDF5256m"


sizes="1 16 256"
units="k m"

sizeg="1"
unitg="g"

ior(){
    local i=$1
    local api=$2
    local size=$3
    local unit=$4
    
    #write 1 blocks 
    local aggr=$(($size*1))
    #check if it is HDF5, and get its alignment value
    local input=`echo "$api"|cut -c1-4`
    local alignment=`echo "$api"|cut -c5-8`

    mkdir -p $CDIR


    #if it is HDF5 and with a specific alignment value setting
    if [[ $input == "HDF5" ]] && [[ ! -z "$alignment" ]]
    then
        #flush data in file close
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}_${aggr}${unit}_w   
        #flush data in data transfer, before file close 
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_f_w    
        #read
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_r
        rm -rf $CDIR/*

        #collectiveIO set on
        #flush data in file close
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}C_${aggr}${unit}_w  --hdf5.collectiveMetadata  
        #flush data in data transfer, before file close 
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}C_${aggr}${unit}_f_w --hdf5.collectiveMetadata  
        #read
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}C_${aggr}${unit}_r --hdf5.collectiveMetadata
 
    #HDF5 with default alignment setting
    elif [[ $input == "HDF5" ]] && [[ -z "$alignment" ]]
    then
        #flush data in file close
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}_${aggr}${unit}_w   
        #flush data in data transfer, before file close 
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_f_w    
        #read
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_r
        rm -rf $CDIR/*
 
        #collectiveIO set on
        #flush data in file close
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}C_${aggr}${unit}_w --hdf5.collectiveMetadata   
        #flush data in data transfer, before file close 
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}C_${aggr}${unit}_f_w  --hdf5.collectiveMetadata 
        #read
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}C_${aggr}${unit}_r --hdf5.collectiveMetadata
    else 
    #MPI, or POSIX
        #flush data in file close
        echo " jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $api -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}_${aggr}${unit}_w" 
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $api -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}_${aggr}${unit}_w   
        #flush data in data transfer, before file close 
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $api -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_f_w    
        #read
        jsrun -n $NPROC -r 1 -a 1 -c 1 $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $api  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_r
 
     fi

     rm -rf $CDIR
}

for i in $(seq 1 1 10); do
    for api in $apis; do
        for size in $sizes; do
            for unit in $units; do
                ior $i $api $size $unit 
            done
        done
        
        for size in $sizeg; do
            for unit in $unitg; do
                ior $i $api $size $unit
            done
        done
    done
done
