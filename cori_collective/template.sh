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
apis="POSIX MPIIO HDF5 HDF5C HDF51m HDF51mC HDF54m HDF54mC HDF516m HDF516mC HDF564m HDF564mC HDF5256m HDF5256mC"

sizes="16 256"
units="k m"

sizeg="1"
unitg="g"

procs="4 8 16"

ior(){
    local i=$1
    local api=$2
    local aggr=$3
    local unit=$4
    local proc=$5 

    if [[ "$unit" == "g" ]]; then
        aggr="1024"
        unit="m"
    fi
   
    #compute per core data size 
    local per=$(($aggr/$proc))

    mkdir -p $CDIR
    if [[ $api == "POSIX" || $api == "MPIIO" || $api == "HDF5" ]]; then
        #flush data in data transfer 
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $api -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_${proc}_f    
        #read
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $api  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_${proc}_r
    elif [[ $api == "HDF5C" ]]; then
        local input="HDF5"
        #flush data in data transfer 
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -J $alignment -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_${proc}_f --hdf5.collectiveMetadata  
        #read
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -J $alignment  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_${proc}_r --hdf5.collectiveMetadata
    else
        local input=`echo "$api"|cut -c1-4`
        local residual=`echo "$api"|cut -c5-8`
        if [[ $residual != *"C"* ]]; then
            local alignment=$residual
            #flush data in data transfer 
            jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -J $alignment -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_${proc}_f    
            #read
            jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -J $alignment  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_${proc}_r
        else
            local alignment=$(echo $residual|sed "s/C//")
            #flush data in data transfer 
            jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -J $alignment -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_${proc}_f --hdf5.collectiveMetadata  
            #read
            jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -J $alignment  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_${proc}_r --hdf5.collectiveMetadata
        fi
    fi 

    rm -rf $CDIR

}
for i in $(seq 1 1 5); do
