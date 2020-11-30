#!/bin/bash -l
#SBATCH -N NNODE
# #SBATCH -p regular
# #SBATCH --qos=premium
#SBATCH -p debug
#SBATCH -A m1248
#SBATCH -t 00:20:00
#SBATCH -C haswell
#SBATCH -L SCRATCH # needs the parallel file system
#SBATCH -J IOR_NNODEnode
#SBATCH -o o%j.ior_NNODEnode
#SBATCH -e o%j.ior_NNODEnode

module swap PrgEnv-gnu PrgEnv-intel

CDIR=${SCRATCH}/ior_data
EXEC=${HOME}/hdf5-work/ior_mod/src/ior

#enable darshan dxt trace 
export MPICH_MPIIO_STATS=1
export MPICH_MPIIO_HINTS_DISPLAY=1
export MPICH_MPIIO_TIMERS=1
export DARSHAN_DISABLE_SHARED_REDUCTION=1
export DXT_ENABLE_IO_TRACE=4

#print romio hints
export ROMIO_PRINT_HINTS=1

#two varying parameters: 1. number of aggregators, 2. read/write buffer size
half_aggr=$((NNODE/2))
quat_aggr=$((NNODE/4))
eqal_aggr=NNODE
doul_aggr=$((NNODE*2))
qudr_aggr=$((NNODE*4)

naggrs="$doul_aggr $qudr_aggr $eqal_aggr $half_aggr $quat_aggr"
stripe_sizes="1m 2m 4m 8m 16m 32m 64m 128m"


ior(){
    local i=$1
    local ncore=$2
    local burst=$3
    local stripe_size=$4
 
    #check file size to determine alignment setting
    size="${burst//k}"
    fileSize=$(($size*$ncore*NNODE/1024))

    if [[ $fileSize -ge 16 ]]; then
        align=16m
    else
        align=1m
    fi
 
    rdir=result_${ncore}_${burst}_${stripe_size}
    mkdir -p $rdir 
    mkdir -p $CDIR
    
    #set stripe size
    lfs setstripe -c 128 -S ${stripe_size} $CDIR
 
    write(){
        ind_write(){
            #independent write
            #flush data in data transfer, before file close
            let NPROC=NNODE*$ncore
            cmd="srun -N NNODE -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -e -w -o $CDIR/ind_${i}_${ncore}_${burst}_${stripe_size}_f --hdf5.collectiveMetadata"
            echo $cmd
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so
            # $cmd
            $cmd &>>$rdir/ind_${ncore}_${burst}_${stripe_size}_f
            export LD_PRELOAD=""
        }

        col_write(){
            local naggr=$1

            hfile=$rdir/aggr_${naggr}
            cp hints/aggr_${naggr} $hfile  

            #load romio hints
            # export ROMIO_HINTS=$hfile
            hvalue=`cat $hfile`
            echo "$hvalue"
            export MPICH_MPIIO_HINTS="*:$hvalue"
            echo $MPICH_MPIIO_HINTS

            #flush data in data transfer, before file close 
            let NPROC=NNODE*$ncore
            cmd="srun -N NNODE -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -e -w -o $CDIR/col_${i}_${ncore}_${burst}_${stripe_size}_${naggr}_f --hdf5.collectiveMetadata"
            echo $cmd
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so
            # $cmd
            $cmd &>>$rdir/col_${ncore}_${burst}_${stripe_size}_${naggr}_f
            export LD_PRELOAD=""
        }

        default_write(){
            #load romio hints
            # cp hints/default $rdir/.
            # export ROMIO_HINTS=$rdir/default
            # hvalue=`cat $rdir/default`
            # echo "$hvalue"
            export MPICH_MPIIO_HINTS="*:"
            echo $MPICH_MPIIO_HINTS

            #flush data in data transfer, before file close 
            let NPROC=NNODE*$ncore
            cmd="srun -N NNODE -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -e -w -o $CDIR/col_${i}_${ncore}_${burst}_${stripe_size}_default_f --hdf5.collectiveMetadata"
            echo $cmd
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so
            # $cmd
            $cmd &>>$rdir/col_${ncore}_${burst}_${stripe_size}_default_f
            export LD_PRELOAD=""
        }


        for naggr in $naggrs; do
            col_write $naggr
        done

        default_write
        ind_write
    }
    

    read(){
        ind_read(){
            #independent read
            let NPROC=NNODE*$ncore
            cmd="srun -N NNODE -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -r -Z -o $CDIR/ind_${i}_${ncore}_${burst}_${stripe_size}_f --hdf5.collectiveMetadata"
            echo $cmd
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so
            # $cmd
            $cmd &>>ind_${ncore}_${burst}_${stripe_size}_r
            export LD_PRELOAD=""
        }

        col_read(){ 
            local naggr=$1
            local buffer=$stripe_size 

            hfile=$rdir/aggr_${naggr}
            #load romio hints
            # export ROMIO_HINTS=$rdir/aggr_${naggr}_${buffer}
            hvalue=`cat $rdir/aggr_${naggr}`
            echo "$hvalue"
            export MPICH_MPIIO_HINTS="*:$hvalue"
            echo $MPICH_MPIIO_HINTS

            let NPROC=NNODE*$ncore
            cmd="srun -N NNODE -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -r -Z -o $CDIR/col_${i}_${ncore}_${burst}_${stripe_size}_${naggr}_f --hdf5.collectiveMetadata"
            echo $cmd
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so
            # $cmd
            $cmd &>>$rdir/col_${ncore}_${burst}_${stripe_size}_${naggr}_r
            export LD_PRELOAD=""
        }
 
        default_read(){ 
            #load romio hints
            # export ROMIO_HINTS=$rdir/default

            export MPICH_MPIIO_HINTS="*:"
            echo $MPICH_MPIIO_HINTS

            let NPROC=NNODE*$ncore
            cmd="srun -N NNODE -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -r -Z -o $CDIR/col_${i}_${ncore}_${burst}_${stripe_size}_default_f --hdf5.collectiveMetadata"
            echo $cmd
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so
            # $cmd
            $cmd &>>$rdir/col_${ncore}_${burst}_${stripe_size}_default_r
            export LD_PRELOAD=""
        }
 
        for naggr in $naggrs; do
            col_read $naggr
        done
    
        default_read
        ind_read
  
    }

    write
    read

    #clean the run
    rm -rf $CDIR
}

