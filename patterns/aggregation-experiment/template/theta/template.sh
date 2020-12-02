#!/bin/bash -l
#COBALT -n ALLOCNODE
#COBALT -q MYQUEUE
#COBALT -t 1:00:00
#COBALT --attrs mcdram=cache:numa=quad 
#COBALT -A CSC250STDM10
#COBALT -O o$COBALT_JOBID.ior_NNODEnode


module load cray-hdf5-parallel
module load darshan

# DARSHAN_PRELOAD=/lus/theta-fs0/software/perftools/darshan/darshan-3.2.1/lib/libdarshan.so

CDIR=/projects/CSC250STDM10/tang/ior_data
EXEC=/gpfs/mira-home/houjun/hdf5-work/ior_mod/src/ior

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
stripe_sizes="1m 2m 4m 8m 16m 32m 64m 128m"

date

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
            cmd="aprun -N $ncore -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -e -w -o $CDIR/ind_${i}_${ncore}_${burst}_${stripe_size}_f --hdf5.collectiveMetadata"
            echo $cmd
            # $cmd
            $cmd &>>$rdir/ind_${ncore}_${burst}_${stripe_size}_f
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
            cmd="aprun -N $ncore -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -e -w -o $CDIR/col_${i}_${ncore}_${burst}_${stripe_size}_${naggr}_f --hdf5.collectiveMetadata"
            echo $cmd
            # $cmd
            $cmd &>>$rdir/col_${ncore}_${burst}_${stripe_size}_${naggr}_f
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
            cmd="aprun -N $ncore -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -e -w -o $CDIR/col_${i}_${ncore}_${burst}_${stripe_size}_default_f --hdf5.collectiveMetadata"
            echo $cmd
            # $cmd
            $cmd &>>$rdir/col_${ncore}_${burst}_${stripe_size}_default_f
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
            cmd="aprun -N $ncore -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -r -Z -o $CDIR/ind_${i}_${ncore}_${burst}_${stripe_size}_f --hdf5.collectiveMetadata"
            echo $cmd
            # $cmd
            $cmd &>>ind_${ncore}_${burst}_${stripe_size}_r
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
            cmd="aprun -N $ncore -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -r -Z -o $CDIR/col_${i}_${ncore}_${burst}_${stripe_size}_${naggr}_f --hdf5.collectiveMetadata"
            echo $cmd
            # $cmd
            $cmd &>>$rdir/col_${ncore}_${burst}_${stripe_size}_${naggr}_r
        }
 
        default_read(){ 
            #load romio hints
            # export ROMIO_HINTS=$rdir/default

            export MPICH_MPIIO_HINTS="*:"
            echo $MPICH_MPIIO_HINTS

            let NPROC=NNODE*$ncore
            cmd="aprun -N $ncore -n $NPROC $EXEC -b $burst -t $burst -i 1 -v -v -v -k -a HDF5 -J $align -c -r -Z -o $CDIR/col_${i}_${ncore}_${burst}_${stripe_size}_default_f --hdf5.collectiveMetadata"
            echo $cmd
            # $cmd
            $cmd &>>$rdir/col_${ncore}_${burst}_${stripe_size}_default_r
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

