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
    else
        if [[ $first_submit == 1 ]]; then 
            echo "Submitting $filename after $last"
            sed -i -e "s/##BSUB/#BSUB/g" -e "s/PREVJOBID/${last}/g" $filename
            first_submit=0
        else 
            echo "Submitting $filename after ${job:5:6}"
            sed -i "s/##BSUB/#BSUB/g" $filename
            sed -i "s/PREVJOBID/${job:5:6}/g" $filename
        fi
    fi
    job=`bsub $filename`



    sleeptime=$[ ( $RANDOM % 10 ) ]
    sleep $sleeptime

done

