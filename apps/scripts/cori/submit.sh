#!/bin/bash

nnode=512
nnode=$1

if [[ -z $1 ]]; then
    echo "specify number of nodes"
    exit
fi

CASES=("vpicio" "bdcatsio" "amrex_single" "amrex_multi" )
curdir=$(pwd)
first_submit=1

./gen.sh $nnode

for mycase in "${CASES[@]}"
do

    echo "${mycase}"
    cd $curdir/${mycase}/${nnode}node
    filename=run_lustre.sh

    if [[ $first_submit == 1 ]]; then
        # Submit first job w/o dependency
        echo "Submitting $filename"
        first_submit=0
        job=`sbatch $filename`
    else
        echo "Submitting $filename after ${job: -8}"
        job=`sbatch -d afterany:${job: -8} $filename`
    fi

    sleeptime=$[ ( $RANDOM % 10 ) ]
    sleep $sleeptime

done

