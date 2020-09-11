#!/bin/bash
# nnode=512
# nts=3
nnode=$1
nts=1
REPEAT_TIME=1

CASES=("vpicio" "bdcatsio" "amrex_single" "amrex_multi")
ndebugq=64
QUEUE_TIME="0:30"

curdir=$(pwd)

for mycase in "${CASES[@]}"
do

    mkdir -p ./${mycase}/${nnode}node/

    QUEUE_NAME=regular
    if (( $nnode <= $ndebugq )); then
        QUEUE_NAME=debug
    fi

    TARGET=./${mycase}/${nnode}node/run_lustre.sh
    cp template.sh $TARGET
    sed -i "s/QUEUE/${QUEUE_NAME}/g"      $TARGET
    sed -i "s/NNODE/${nnode}/g"           $TARGET
    sed -i "s/REPEATTIME/$REPEAT_TIME/g"  $TARGET
    sed -i "s/QTIME/$QUEUE_TIME/g"  $TARGET
    # sed -i "s/QTIME/1:30:00/g"  $TARGET
    sed -i "s/APP/${mycase}_${nts}ts/g"  $TARGET
    if [[ $mycase == "vpicio" ]]; then
        INPUT1="\$CDIR/${nnode}node_${nts}ts_hdf5_1.h5 $nts 0"
        INPUT2="\$CDIR/${nnode}node_${nts}ts_hdf5_2.h5 $nts 0"
        # INPUT3="\$CDIR/${nnode}node_${nts}ts_hdf5_3.h5 $nts 0"
        EXEC1="$curdir/../../vpicio_hdf5/vpicio_uni_h5.exe"
        EXEC2="$curdir/../../vpicio_mod/vpicio_uni_h5.exe"
        BSIZE=32
        NB=8
        sed -i "s!MYCASE!$mycase!g"  $TARGET

    elif [[ $mycase == "bdcatsio" ]]; then
        INPUT1="\$CDIR/${nnode}node_${nts}ts_hdf5_1.h5 $nts 0"
        INPUT2="\$CDIR/${nnode}node_${nts}ts_hdf5_2.h5 $nts 0"
        # INPUT3="\$CDIR/${nnode}node_${nts}ts_hdf5_3.h5 $nts 0"
        EXEC1="$curdir/../../bdcats_hdf5/bdcatsio.exe"
        EXEC2="$curdir/../../bdcats_mod/bdcatsio.exe"
        BSIZE=32
        NB=8
        sed -i "s!MYCASE!vpicio!g"  $TARGET

    elif [[ $mycase == "amrex_single" ]]; then
        INPUT1="$curdir/inputs_single_2048"
        INPUT2="$curdir/inputs_single_2048"
        # INPUT3="$curdir/inputs_single_2048"
        EXEC1="$curdir/../../amrex_hdf5/Tests/HDF5Benchmark/main3d.gnu.TPROF.MPI.ex"
        EXEC2="$curdir/../../amrex_mod/Tests/HDF5Benchmark/main3d.gnu.TPROF.MPI.ex"
        BSIZE=1000
        NB=100
        sed -i "s!MYCASE!$mycase!g"  $TARGET

    elif [[ $mycase == "amrex_multi" ]]; then
        INPUT1="$curdir/inputs_multi_128"
        INPUT2="$curdir/inputs_multi_128"
        # INPUT3="$curdir/inputs_multi_128"
        EXEC1="$curdir/../../amrex_hdf5/Tests/HDF5Benchmark/main3d.gnu.TPROF.MPI.ex"
        EXEC2="$curdir/../../amrex_mod/Tests/HDF5Benchmark/main3d.gnu.TPROF.MPI.ex"
        BSIZE=1000
        NB=100
	sed -i "s!#AMREX_MULTI!!g"  $TARGET
        sed -i "s!MYCASE!$mycase!g"  $TARGET

    else
        echo "Error with mycase $mycase"
    fi

    sed -i "s!ARGV1!$INPUT1!g"  $TARGET
    sed -i "s!ARGV2!$INPUT2!g"  $TARGET
    # sed -i "s!ARGV3!$INPUT3!g"  $TARGET
    sed -i "s!EXEPATH1!$EXEC1!g"  $TARGET
    sed -i "s!EXEPATH2!$EXEC2!g"  $TARGET
    sed -i "s!BLKSIZE!$BSIZE!g"  $TARGET
    sed -i "s!NBLK!$NB!g"  $TARGET

done
