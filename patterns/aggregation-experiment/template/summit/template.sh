#!/bin/bash -l
#BSUB -P CSC300
#BSUB -W 2:00
#BSUB -nnodes NNODE
##BSUB -w ended(PREVJOBID)
# #BSUB -alloc_flags gpumps
#BSUB -J IOR_NNODEnode
#BSUB -o o%J.ior_NNODEnode
#BSUB -e o%J.ior_NNODEnode

EXEC=/gpfs/alpine/csc300/world-shared/hdf5-work/ior_mod/src/ior
LD_LIBRARY_PATH=/gpfs/alpine/csc300/world-shared/gnu_build/hdf5-1.10.6.mod/build/hdf5/lib:$LD_LIBRARY_PATH
module load darshan-runtime/3.2.1


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

#target repetitions
target_repetitions=9
per_write=3
total_write=0
check=0

ior(){
    local i=$1
    local ncore=$2
    local burst=$3
 
    #check file size to determine alignment setting
    size="${burst//k}"
    fileSize=$(($size*$ncore*NNODE/1024))
    CDIR=/gpfs/alpine/scratch/houjun/csc300/ior_data/ior_${ncore}_${burst}

    if [[ ! -d $CDIR ]]; then
        mkdir -p $CDIR
    fi

    if [[ $fileSize -ge 16 ]]; then
        align=16m
    else
        align=1m
    fi

    #check read/write repetitions, target: 9 repetitions
    read_line="${ncore}_${burst} r"
    total_line=${ncore}_${burst}
    total_count=0
    read_count=0

    read_count=`cat complete|grep "$read_line"|wc -l`
    total_count=`cat complete|grep "$total_line"|wc -l`
    

    rdir=result_${ncore}_${burst}
    mkdir -p $rdir
    write_count=$((($total_count-$read_count)*$per_write+${total_write}))

    ior_write(){
        ind_write(){
            #independent write
            #flush data in data transfer, before file close
            jsrun -n NNODE -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -e -w -o $CDIR/ind_${i}_${ncore}_${burst}_f&>>$rdir/ind_${ncore}_${burst}_f 
        }
        col_write(){
            local naggr=$1
            local buffer=$2  

            hfile=$rdir/aggr_${naggr}_${buffer}
            cp hints/aggr_${naggr}_${buffer} $hfile  

            #load romio hints
            export ROMIO_HINTS=$hfile

            #flush data in data transfer, before file close 
            jsrun -n NNODE -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -e -w -o $CDIR/col_${i}_${ncore}_${burst}_${naggr}_${buffer}_f&>>$rdir/col_${ncore}_${burst}_${naggr}_${buffer}_f
        }

        default_write(){
            #load romio hints
            export ROMIO_HINTS=" "

            #flush data in data transfer, before file close 
            jsrun -n NNODE -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -e -w -o $CDIR/col_${i}_${ncore}_${burst}_default_f&>>$rdir/col_${ncore}_${burst}_default_f
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
            jsrun -n NNODE -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -r -o $CDIR/ind_${i}_${ncore}_${burst}_f&>>$rdir/ind_${ncore}_${burst}_r   
        }
        col_read(){ 
            local naggr=$1
            local buffer=$2  

            #load romio hints
            export ROMIO_HINTS=$rdir/aggr_${naggr}_${buffer}
            jsrun -n NNODE -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -r -o $CDIR/col_${i}_${ncore}_${burst}_${naggr}_${buffer}_f&>>$rdir/col_${ncore}_${burst}_${naggr}_${buffer}_r   
        }
 
        default_read(){ 
            #load romio hints
            export ROMIO_HINTS=" "
            jsrun -n NNODE -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -r -o $CDIR/col_${i}_${ncore}_${burst}_default_f&>>$rdir/col_${ncore}_${burst}_default_r     
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
        if [[ -f $CDIR/ind_${i}_${ncore}_${burst}_f && $check -ne 2 ]]; then
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

