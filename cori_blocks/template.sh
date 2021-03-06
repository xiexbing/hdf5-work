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
#module load hdf5/1.10.3

let NPROC=NNODE

CDIR=${SCRATCH}/ior_data
EXEC=hdf5-work/ior/src/ior

export LD_LIBRARY_PATH=/cori/hdf5-1.10.6/build/hdf5/lib:$LD_LIBRARY_PATH
export MPICH_MPIIO_STATS=1
export MPICH_MPIIO_HINTS_DISPLAY=1
export MPICH_MPIIO_TIMERS=1
export DARSHAN_DISABLE_SHARED_REDUCTION=1
export DXT_ENABLE_IO_TRACE=4


#for the hdf5 setting with specific alignment value, the api is HDF5+alignment_setting_value, for the runs with hdf5 setting we perform the ior with no collective i/o for hdf5 metadata, and with collective i/o for hdf5 metadata.
apis="POSIX MPIIO HDF5 HDF51m HDF54m HDF516m HDF564m HDF5256m"

sizes="16 256"
units="k m"

sizeg="1"
unitg="g"

blocks="4 8 16"

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

    mkdir -p $CDIR
    lfs setstripe -c 248 -S 16m $CDIR

    if [[ $api == "POSIX" || $api == "MPIIO" || $api == "HDF5" ]]; then
        export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so 
        #flush data in data transfer 
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $api -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_${nblock}_f    
        #read
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $api  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_${nblock}_r
        export LD_PRELOAD=""
    elif [[ $api == "HDF5C" ]]; then
        local input="HDF5"
        export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so 
        #flush data in data transfer 
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_${nblock}_f --hdf5.collectiveMetadata  
        #read
        $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_${nblock}_r --hdf5.collectiveMetadata
        export LD_PRELOAD=""
    else
        local input=`echo "$api"|cut -c1-4`
        local residual=`echo "$api"|cut -c5-8`
        if [[ $residual != *"C"* ]]; then
            local alignment=$residual
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so 
            #flush data in data transfer 
            $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_${nblock}_f    
            #read
            $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_${nblock}_r
            export LD_PRELOAD=""
        else
            local alignment=$(echo $residual|sed "s/C//")
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so 
            #flush data in data transfer 
            $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment -e -w -o $CDIR/${NPROC}p_${i}_${api}_f&>>${api}_${aggr}${unit}_${nblock}_f --hdf5.collectiveMetadata  
            #read
            $run_cmd $EXEC -b ${aggr}${unit} -t ${size}${unit} -i 1 -v -v -v -k -a $input -J $alignment  -r -C -o $CDIR/${NPROC}p_${i}_${api}_f &>>${api}_${aggr}${unit}_${nblock}_r --hdf5.collectiveMetadata
            export LD_PRELOAD=""
        fi
    fi 

    rm -rf $CDIR

}

for i in $(seq 1 1 5); do

