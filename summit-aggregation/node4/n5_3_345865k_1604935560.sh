#!/bin/bash -l
#BSUB -P stf008 
#BSUB -W 2:00
#BSUB -nnodes 4
#BSUB -w ended(469277)
# #BSUB -alloc_flags gpumps
#BSUB -J IOR_4node
#BSUB -o o%J.ior_4node
#BSUB -e o%J.ior_4node

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
half_aggr=$((4/2))
quat_aggr=$((4/4))
eqal_aggr=4

naggrs="$eqal_aggr $half_aggr $quat_aggr"
buff_sizes="1M 4M 16M 64M 256M"

ior(){
    local i=$1
    local ncore=$2
    local burst=$3
 
    #check file size to determine alignment setting
    size="${burst//k}"
    fileSize=$(($size*$ncore*4/1024))

    if [[ $fileSize -ge 16 ]]; then
        align=16m
    else
        align=1m
    fi

    rdir=result_${ncore}_${burst}
    mkdir -p $rdir 
    mkdir -p $CDIR
 
    write(){
        ind_write(){
            #independent write
            #flush data in data transfer, before file close
            jsrun -n 4 -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -e -w -o $CDIR/ind_${i}_${ncore}_${burst}_f&>>$rdir/ind_${ncore}_${burst}_f 
        }

        col_write(){
            local naggr=$1
            local buffer=$2  

            hfile=$rdir/aggr_${naggr}_${buffer}_${ncore}
            if [[ ! -f $hfile ]]; then
                cp hints/aggr_${naggr}_${buffer} $hfile  
                list="cb_config_list "
                if [[ $naggr -le 4 ]]; then
                    ag(){
                        local na=$1
                        rank=$((($na-1)*$ncore))
                        list=$list" $rank"
                    }
                    for na in $(seq 1 1 $naggr); do
                        ag $na
                    done
                else
                    daggr=4
                    dg(){
                        local na=$1
                        inNode=$(($naggr/4))
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
                   for na in $(seq 1 1 4); do
                       dg $na
                   done
                fi
                echo $list>>$hfile
            fi

            #load romio hints
            export ROMIO_HINTS=$hfile

            #flush data in data transfer, before file close 
            jsrun -n 4 -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -e -w -o $CDIR/col_${i}_${ncore}_${burst}_${naggr}_${buffer}_f&>>$rdir/col_${ncore}_${burst}_${naggr}_${buffer}_f 
        }

        default_write(){
            #load romio hints
            cp hints/default $rdir/.
            export ROMIO_HINTS=$rdir/default

            #flush data in data transfer, before file close 
            jsrun -n 4 -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -e -w -o $CDIR/col_${i}_${ncore}_${burst}_default_f&>>$rdir/col_${ncore}_${burst}_default_f
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
            jsrun -n 4 -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -r -Z -o $CDIR/ind_${i}_${ncore}_${burst}_f&>>ind_${ncore}_${burst}_r     
        }

        col_read(){ 
            local naggr=$1
            local buffer=$2  

            hfile=$rdir/aggr_${naggr}_${buffer}_${ncore}
            #load romio hints
            export ROMIO_HINTS=$rdir/aggr_${naggr}_${buffer}
            jsrun -n 4 -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -r -Z -o $CDIR/col_${i}_${ncore}_${burst}_${naggr}_${buffer}_f&>>$rdir/col_${ncore}_${burst}_${naggr}_${buffer}_r       
        }
        for naggr in $naggrs; do
            for buffer in $buff_sizes; do
                col_read $naggr $buffer
            done
        done
 
        default_read(){ 
            #load romio hints
            export ROMIO_HINTS=$rdir/default
            jsrun -n 4 -r 1 -a $ncore -c $ncore $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -r -Z -o $CDIR/col_${i}_${ncore}_${burst}_default_f&>>$rdir/col_${ncore}_${burst}_default_r    
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


for i in $(seq 1 1 3); do
for ncore in '3'; do
for burst in '345865k'; do
ior $i $ncore $burst
done
done
done
echo n5_3_345865k done
rm -rf /tmp/jsm.login1.4069
