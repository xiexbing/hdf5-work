#!/bin/bash -l
#SBATCH -N NNODE
#SBATCH -p regular
# #SBATCH --qos=premium
# #SBATCH -p debug
#SBATCH -A m1248
#SBATCH -t 02:00:00
#SBATCH -C haswell
#SBATCH -L SCRATCH # needs the parallel file system
#SBATCH -J IOR_NNODEnode
#SBATCH -o o%j.ior_NNODEnode
#SBATCH -e o%j.ior_NNODEnode


let NPROC=NNODE
mydir=$(pwd)
CDIR=${SCRATCH}/ior_data
EXEC=${mydir}/../../ior/src/ior

export LD_LIBRARY_PATH=/global/homes/h/houhun/cori/hdf5-1.10.6/build/hdf5/lib:$LD_LIBRARY_PATH
export MPICH_MPIIO_STATS=1
export MPICH_MPIIO_HINTS_DISPLAY=1
export MPICH_MPIIO_TIMERS=1
export DARSHAN_DISABLE_SHARED_REDUCTION=1
export DXT_ENABLE_IO_TRACE=4


#for the hdf5 setting with specific alignment value, the api is HDF5+alignment_setting_value, for the runs with hdf5 setting we perform the ior with no collective i/o for hdf5 metadata, and with collective i/o for hdf5 metadata.
apis="POSIX MPIIO HDF5 HDF51m HDF54m HDF516m HDF564m HDF5256m"
blocks="4 8 16"

sizes="16 256"
units="k m"
 
sizeg="1"
unitg="g"

run_cmd="srun -N NNODE -n $NPROC"

ior(){
    local i=$1
    local api=$2
    local aggr=$3
    local unit=$4
    local nblock=$5
 
    if [[ "$unit" == "g" ]]; then
        aggr="1024"
        unit="m"
    fi
    #compute per block size
    local size=$(($aggr/$nblock)) 
    
    #check if it is HDF5, and get its alignment value
    local input=`echo "$api"|cut -c1-4`
    local alignment=`echo "$api"|cut -c5-8`
   

    mkdir -p $CDIR


    #if it is HDF5 and with a specific alignment value setting
    if [[ $input == "HDF5" ]] && [[ ! -z "$alignment" ]]
    then
        #flush data in file close
        export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so 
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}_${aggr}${unit}_${nblock}_w   
        #flush data in data transfer, before file close 
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_${nblock}_f_w    
        #read
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_${nblock}_r
        export LD_PRELOAD=""
        rm -rf $CDIR/*

        #collectiveIO set on
        #flush data in file close
        export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so 
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}C_${aggr}${unit}_${nblock}_w  --hdf5.collectiveMetadata  
        #flush data in data transfer, before file close 
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}C_${aggr}${unit}_${nblock}_f_w --hdf5.collectiveMetadata  
        #read
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}C_${aggr}${unit}_${nblock}_r --hdf5.collectiveMetadata
        export LD_PRELOAD=""
 
    #HDF5 with default alignment setting
    elif [[ $input == "HDF5" ]] && [[ -z "$alignment" ]]
    then
        #flush data in file close
        export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so 
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}_${aggr}${unit}_${nblock}_w   
        #flush data in data transfer, before file close 
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_${nblock}_f_w    
        #read
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_${nblock}_r
        export LD_PRELOAD=""
        rm -rf $CDIR/*
 
        #collectiveIO set on
        #flush data in file close
        export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so 
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}C_${aggr}${unit}_${nblock}_w --hdf5.collectiveMetadata   
        #flush data in data transfer, before file close 
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}C_${aggr}${unit}_${nblock}_f_w  --hdf5.collectiveMetadata 
        #read
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}C_${aggr}${unit}_${nblock}_r --hdf5.collectiveMetadata
        export LD_PRELOAD=""
    else 
    #MPI, or POSIX
        #flush data in file close
        export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so 
        echo " $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $api -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}_${aggr}${unit}_${nblock}_w" 
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $api -w -o $CDIR/${NPROC}p_${i}_${api}&>>${api}_${aggr}${unit}_${nblock}_w   
        #flush data in data transfer, before file close 
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $api -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_${nblock}_f_w    
        #read
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $api  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_${nblock}_r
        export LD_PRELOAD=""
 
     fi

     rm -rf $CDIR
}

for i in $(seq 1 1 5); do
    for api in $apis; do
        for aggr in $sizes; do
            for unit in $units; do
                for nblock in $blocks; do
                    ior $i $api $aggr $unit $nblock 
                done
            done
        done
        for aggr in $sizeg; do
            for unit in $unitg; do
                for nblock in $blocks; do
                    ior $i $api $aggr $unit $nblock
                done
            done
       done
    done
done
