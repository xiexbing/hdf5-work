#!/bin/bash -l
#BSUB -P stf008 
#BSUB -W 2:00
#BSUB -nnodes NNODE
##BSUB -w ended(PREVJOBID)
# #BSUB -alloc_flags gpumps
#BSUB -J IOR_NNODEnode
#BSUB -o o%J.ior_NNODEnode
#BSUB -e o%J.ior_NNODEnode

CDIR=ior_data
EXEC=/gpfs/alpine/stf008/scratch/bing/ior_mod/src/ior
LD_LIBRARY_PATH=/gpfs/alpine/csc300/world-shared/gnu_build/hdf5-1.10.6.mod/build/hdf5/lib:$LD_LIBRARY_PATH

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
            jsrun -n NNODE -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -e -w -o $CDIR/ind_${i}_${ncore}_${burst}_${stripe_size}_f&>>$rdir/ind_${ncore}_${burst}_${stripe_size}_f --hdf5.collectiveMetadata 
        }

        col_write(){
            local naggr=$1
            local buffer=$2  

            hfile=$rdir/aggr_${naggr}_${buffer}_${ncore}
            if [[ ! -f $hfile ]]; then
                cp hints/aggr_${naggr}_${buffer} $hfile  
                list="cb_config_list "
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
                echo $list>>$hfile
            fi

            #load romio hints
            export ROMIO_HINTS=$hfile

            #flush data in data transfer, before file close 
            jsrun -n NNODE -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -e -w -o $CDIR/col_${i}_${ncore}_${burst}_${stripe_size}_${naggr}_${buffer}_f&>>$rdir/col_${ncore}_${burst}_${stripe_size}_${naggr}_${buffer}_f --hdf5.collectiveMetadata
        }

        default_write(){
            #load romio hints
            cp hints/default $rdir/.
            export ROMIO_HINTS=$rdir/default

            #flush data in data transfer, before file close 
            jsrun -n NNODE -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -e -w -o $CDIR/col_${i}_${ncore}_${burst}_${stripe_size}_default_f&>>$rdir/col_${ncore}_${burst}_${stripe_size}_default_f --hdf5.collectiveMetadata
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
            jsrun -n NNODE -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -r -Z -o $CDIR/ind_${i}_${ncore}_${burst}_${stripe_size}_f&>>ind_${ncore}_${burst}_${stripe_size}_r --hdf5.collectiveMetadata     
        }

        col_read(){ 
            local naggr=$1
            local buffer=$2  

            hfile=$rdir/aggr_${naggr}_${buffer}_${ncore}
            #load romio hints
            export ROMIO_HINTS=$rdir/aggr_${naggr}_${buffer}
            jsrun -n NNODE -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -r -Z -o $CDIR/col_${i}_${ncore}_${burst}_${stripe_size}_${naggr}_${buffer}_f&>>$rdir/col_${ncore}_${burst}_${stripe_size}_${naggr}_${buffer}_r --hdf5.collectiveMetadata      
        }
        for naggr in $naggrs; do
            for buffer in $buff_sizes; do
                col_read $naggr $buffer
            done
        done
 
        default_read(){ 
            #load romio hints
            export ROMIO_HINTS=$rdir/default
            jsrun -n NNODE -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -r -Z -o $CDIR/col_${i}_${ncore}_${burst}_${stripe_size}_default_f&>>$rdir/col_${ncore}_${burst}_${stripe_size}_default_r --hdf5.collectiveMetadata       
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

