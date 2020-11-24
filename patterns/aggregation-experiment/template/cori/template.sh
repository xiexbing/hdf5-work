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

naggrs="$eqal_aggr $half_aggr $quat_aggr"
buff_sizes="1M 4M 16M 64M 256M"
stripe_sizes="1m 4m 16m 32m 64m"


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
            local buffer=$2  

            hfile=$rdir/aggr_${naggr}_${buffer}_${ncore}
            if [[ ! -f $hfile ]]; then
                cp hints/aggr_${naggr}_${buffer} $hfile  
                list=":cb_config_list="
                if [[ $naggr -le NNODE ]]; then
                    ag(){
                        local na=$1
                        rank=$((($na-1)*$ncore))
                        list=$list" $rank"
                    }
                    for na in $(seq 1 1 $naggr); do
                        ag $na
                    done
                else
                    daggr=NNODE
                    dg(){
                        local na=$1
                        inNode=$(($naggr/NNODE))
                        per(){
                            local p=$1
                            n=$((($na-1)*$ncore))
                            rank=$(($n+$p-1))
                            list=$list" $rank"
                        }
                        for p in $(seq 1 1 $inNode); do
                            per $p
                        done
                   }
                   for na in $(seq 1 1 NNODE); do
                       dg $na
                   done
                fi
                # Tang commented out for Cori
                # echo $list>>$hfile
            fi

            #load romio hints
            # export ROMIO_HINTS=$hfile
            hvalue=`cat $hfile`
            echo "$hvalue"
            export MPICH_MPIIO_HINTS="*:$hvalue"
            echo $MPICH_MPIIO_HINTS

            #flush data in data transfer, before file close 
            let NPROC=NNODE*$ncore
            cmd="srun -N NNODE -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -e -w -o $CDIR/col_${i}_${ncore}_${burst}_${stripe_size}_${naggr}_${buffer}_f --hdf5.collectiveMetadata"
            echo $cmd
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so
            # $cmd
            $cmd &>>$rdir/col_${ncore}_${burst}_${stripe_size}_${naggr}_${buffer}_f
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
            for buffer in $buff_sizes; do
                col_write $naggr $buffer
            done
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
            local buffer=$2  

            hfile=$rdir/aggr_${naggr}_${buffer}_${ncore}
            #load romio hints
            # export ROMIO_HINTS=$rdir/aggr_${naggr}_${buffer}
            hvalue=`cat $rdir/aggr_${naggr}_${buffer}`
            echo "$hvalue"
            export MPICH_MPIIO_HINTS="*:$hvalue"
            echo $MPICH_MPIIO_HINTS

            let NPROC=NNODE*$ncore
            cmd="srun -N NNODE -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -r -Z -o $CDIR/col_${i}_${ncore}_${burst}_${stripe_size}_${naggr}_${buffer}_f --hdf5.collectiveMetadata"
            echo $cmd
            export LD_PRELOAD=/global/common/cori_cle7/software/darshan/3.1.7/lib/libdarshan.so
            # $cmd
            $cmd &>>$rdir/col_${ncore}_${burst}_${stripe_size}_${naggr}_${buffer}_r
            export LD_PRELOAD=""
        }
        for naggr in $naggrs; do
            for buffer in $buff_sizes; do
                col_read $naggr $buffer
            done
        done
 
        default_read(){ 
            #load romio hints
            # export ROMIO_HINTS=$rdir/default
            hvalue=`cat $rdir/default`
            echo "$hvalue"
            export MPICH_MPIIO_HINTS="*:$hvalue"
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
            for buffer in $buff_sizes; do
                col_read $naggr $buffer
            done
        done
    
        default_read
        ind_read
  
    }

    write
    read

    #clean the run
    rm -rf $CDIR
}

