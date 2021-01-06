#!/bin/bash -l
#SBATCH -N NNODE
# #SBATCH --qos=premium
#SBATCH -A m1248
# #SBATCH -p debug
# #SBATCH -t 00:30:00
#SBATCH -p regular
#SBATCH -t 01:00:00
#SBATCH -C haswell
#SBATCH -L SCRATCH # needs the parallel file system
#SBATCH -J IOR_NNODEnode
#SBATCH -o o%j.ior_NNODEnode
#SBATCH -e o%j.ior_NNODEnode

module swap PrgEnv-gnu PrgEnv-intel

EXEC=$CFS/m1248/tang/hdf5-work/ior_mod/src/ior
# LD_LIBRARY_PATH=/gpfs/alpine/csc300/world-shared/gnu_build/hdf5-1.10.6.mod/build/hdf5/lib:$LD_LIBRARY_PATH
# module load darshan-runtime/3.2.1

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
qudr_aggr=$((NNODE*4))


naggrs="$doul_aggr $qudr_aggr $eqal_aggr $half_aggr $quat_aggr"
buff_sizes="1M 4M 16M 64M 256M"
stripe_sizes="1m 2m 4m 8m 16m 32m 64m 128m"

#target repetitions
target_repetitions=9
per_write=3
total_write=0
check=0

ior(){
    local i=$1
    local ncore=$2
    local burst=$3
    local stripe_size=$4
 
    #check file size to determine alignment setting
    size="${burst//k}"
    fileSize=$(($size*$ncore*NNODE/1024))
    CDIR=$SCRATCH/ior_data/ior_${ncore}_${burst}_${stripe_size}

    if [[ ! -d $CDIR ]]; then
        mkdir -p $CDIR
    fi

    lfs setstripe -c 128 -S ${stripe_size} $CDIR

    if [[ $fileSize -ge 16 ]]; then
        align=16m
    else
        align=1m
    fi

    #check read/write repetitions, target: 9 repetitions
    read_line="${ncore}_${burst}_${stripe_size} r"
    total_line=${ncore}_${burst}_${stripe_size}
    total_count=0
    read_count=0

    read_count=`cat complete|grep "$read_line"|wc -l`
    total_count=`cat complete|grep "$total_line"|wc -l`
    

    rdir=result_${ncore}_${burst}_${stripe_size}
    mkdir -p $rdir
    write_count=$((($total_count-$read_count)*$per_write+${total_write}))

    ior_write(){
        ind_write(){
            #independent write
            #flush data in data transfer, before file close
            let NPROC=NNODE*$ncore
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so
            srun -N NNODE -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -e -w -o $CDIR/ind_${i}_${ncore}_${burst}_${stripe_size}_f&>>$rdir/ind_${ncore}_${burst}_${stripe_size}_f 
            export LD_PRELOAD=""
        }
        col_write(){
            local naggr=$1
            local buffer=$2  

            #load romio hints
            # export ROMIO_HINTS=$hfile
            hfile=$rdir/aggr_${naggr}
            cp hints/aggr_${naggr} $hfile  
            hvalue=`cat $hfile`
            echo "$hvalue"
            export MPICH_MPIIO_HINTS="*:$hvalue"
            echo $MPICH_MPIIO_HINTS

            #flush data in data transfer, before file close 
            let NPROC=NNODE*$ncore
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so
            srun -N NNODE -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -e -w -o $CDIR/col_${i}_${ncore}_${burst}_${naggr}_${buffer}_${stripe_size}_f&>>$rdir/col_${ncore}_${burst}_${naggr}_${buffer}_${stripe_size}_f
            export LD_PRELOAD=""
        }

        default_write(){
            #load romio hints
            # export ROMIO_HINTS=" "
            export MPICH_MPIIO_HINTS="*:"
            echo $MPICH_MPIIO_HINTS

            #flush data in data transfer, before file close 
            let NPROC=NNODE*$ncore
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so
            srun -N NNODE -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -e -w -o $CDIR/col_${i}_${ncore}_${burst}_default_${stripe_size}_f&>>$rdir/col_${ncore}_${burst}_default_${stripe_size}_f
            export LD_PRELOAD=""
        }
        for naggr in $naggrs; do
            for buffer in $buff_sizes; do
                col_write $naggr $buffer
            done
        done

        default_write
        ind_write
    }
    
    ior_read(){
        ind_read(){
            #independent read
            let NPROC=NNODE*$ncore
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so
            srun -N NNODE -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -r -o $CDIR/ind_${i}_${ncore}_${burst}_${stripe_size}_f&>>$rdir/ind_${ncore}_${burst}_${stripe_size}_r   
            export LD_PRELOAD=""
        }
        col_read(){ 
            local naggr=$1
            local buffer=$2  

            #load romio hints
            # export ROMIO_HINTS=$rdir/aggr_${naggr}_${buffer}
            hfile=$rdir/aggr_${naggr}
            hvalue=`cat $rdir/aggr_${naggr}`
            echo "$hvalue"
            export MPICH_MPIIO_HINTS="*:$hvalue"
            echo $MPICH_MPIIO_HINTS

            let NPROC=NNODE*$ncore
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so
            srun -N NNODE -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -r -o $CDIR/col_${i}_${ncore}_${burst}_${naggr}_${buffer}_${stripe_size}_f&>>$rdir/col_${ncore}_${burst}_${naggr}_${buffer}_${stripe_size}_r   
            export LD_PRELOAD=""
        }
 
        default_read(){ 
            #load romio hints
            # export ROMIO_HINTS=" "
            export MPICH_MPIIO_HINTS="*:"
            echo $MPICH_MPIIO_HINTS

            let NPROC=NNODE*$ncore
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so
            srun -N NNODE -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -r -o $CDIR/col_${i}_${ncore}_${burst}_default_${stripe_size}_f&>>$rdir/col_${ncore}_${burst}_default_${stripe_size}_r     
            export LD_PRELOAD=""
        }


        for naggr in $naggrs; do
            for buffer in $buff_sizes; do
                col_read $naggr $buffer
            done
        done

        default_read
        ind_read
    }
    
    if [[ $read_count -lt $target_repetitions ]]; then
        if [[ -f $CDIR/ind_${i}_${ncore}_${burst}_${stripe_size}_f && $check -ne 2 ]]; then
            ior_read 
            echo $read_line>>complete
            read_count=$(($read_count+1))
            check=1
        fi 
    fi

 
    if [[ $check -eq 0 || $check -eq 2 ]]; then
        if [[ $write_count -lt $target_repetitions ]]; then
           ior_write
           write_count=$(($write_count+1))
           total_write=$(($total_write+1))
           check=2
        elif [[ $read_count -lt $target_repetitions && $i -eq 1 ]]; then
            ior_write
            write_count=$(($write_count+1))
            total_write=$(($total_write+1))
            check=2 
        fi
    fi

    if [[ $total_write -eq $per_write ]]; then
        echo $total_line>>complete
    fi 

    if [[ $read_count -ge $target_repetitions ]]; then
        rm -rf $CDIR
    fi
   
    echo "bing, read count, $read_count, write count, $write_count, total write, $total_write" 

}

