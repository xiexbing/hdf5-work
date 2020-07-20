#!/bin/bash -l
#BSUB -P projID 
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
EXEC=ior/src/ior
LD_LIBRARY_PATH=hdf5-1.10.6/hdf5/lib:$LD_LIBRARY_PATH


export MPICH_MPIIO_STATS=1
export MPICH_MPIIO_HINTS_DISPLAY=1
export MPICH_MPIIO_TIMERS=1
export DARSHAN_DISABLE_SHARED_REDUCTION=1
export DXT_ENABLE_IO_TRACE=4


#for the hdf5 setting with specific alignment value, the api is HDF5+alignment_setting_value, for the runs with hdf5 setting we perform the ior with no collective i/o for hdf5 metadata, and with collective i/o for hdf5 metadata.
apis="POSIX MPIIO HDF5 HDF51m HDF54m HDF516m HDF564m HDF5256m"
procs="4 8 16"

sizes="16 256"
units="k m"
 
sizeg="1"
unitg="g"

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
    #compute per core 
    local per=$(($aggr/$proc)) 
    #check if it is HDF5, and get its alignment value
    local input=`echo "$api"|cut -c1-4`
    local alignment=`echo "$api"|cut -c5-8`
   

    mkdir -p $CDIR


    #if it is HDF5 and with a specific alignment value setting
    if [[ $input == "HDF5" ]] && [[ ! -z "$alignment" ]]
    then
        #flush data in file close
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -J $alignment -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}_${aggr}${unit}_${proc}_w   
        #flush data in data transfer, before file close 
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -J $alignment -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_${proc}_f_w    
        #read
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -J $alignment  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_${proc}_r
        if [[ $NPROC != 2 && $i != 5 ]]; then
            rm -rf $CDIR/*
        fi
        #collectiveIO set on
        #flush data in file close
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -J $alignment -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}C_${aggr}${unit}_${proc}_w  --hdf5.collectiveMetadata  
        #flush data in data transfer, before file close 
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -J $alignment -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}C_${aggr}${unit}_${proc}_f_w --hdf5.collectiveMetadata  
        #read
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -J $alignment  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}C_${aggr}${unit}_${proc}_r --hdf5.collectiveMetadata
 
    #HDF5 with default alignment setting
    elif [[ $input == "HDF5" ]] && [[ -z "$alignment" ]]
    then
        #flush data in file close
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}_${aggr}${unit}_${proc}_w   
        #flush data in data transfer, before file close 
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_${proc}_f_w    
        #read
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_${proc}_r
        if [[ $NPROC != 2 && $i != 5 ]]; then
            rm -rf $CDIR/*
        fi
 
        #collectiveIO set on
        #flush data in file close
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}C_${aggr}${unit}_${proc}_w --hdf5.collectiveMetadata   
        #flush data in data transfer, before file close 
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}C_${aggr}${unit}_${proc}_f_w  --hdf5.collectiveMetadata 
        #read
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $input -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}C_${aggr}${unit}_${proc}_r --hdf5.collectiveMetadata
    else 
    #MPI, or POSIX
        #flush data in file close
        echo " jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $api -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}_${aggr}${unit}_${proc}_w" 
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $api -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}_${aggr}${unit}_${proc}_w   
        #flush data in data transfer, before file close 
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $api -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_${proc}_f_w    
        jsrun -n $NPROC -r 1 -a $proc -c $proc $EXEC -b ${per}${unit} -t ${per}${unit} -i 1 -v -v -v -k -a $api  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_${proc}_r
 
     fi
     if [[ $NPROC != 2 && $i != 5 ]]; then
         rm -rf $CDIR
     fi
}

for i in $(seq 1 1 5); do
    for api in $apis; do
        for aggr in $sizes; do
            for unit in $units; do
                for proc in $procs; do
                    ior $i $api $aggr $unit $proc 
                done
            done
        done
        for aggr in $sizeg; do
            for unit in $unitg; do
                for proc in $procs; do
                    ior $i $api $aggr $unit $proc
                done
            done
       done
    done
done

rm -rf /tmp/jsm.$(hostname).4069 
