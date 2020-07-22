#!/bin/bash

MIN_PROC=2
MAX_PROC=128

curdir=$(pwd)
./gen.sh

last=`bjobs|awk '{print $1}'|tail -1`
first_submit=1
for (( j = $MIN_PROC; j <= $MAX_PROC ; j*=4 )); do

    cd $curdir/node${j}
    filename=run.sh

    if [[ $first_submit == 1 && "$last" == "" ]]; then
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

