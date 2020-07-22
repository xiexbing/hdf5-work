#!/bin/bash

MIN_PROC=2
MAX_PROC=128

curdir=$(pwd)
./gen.sh

first_submit=1
REPEAT=3

for (( j = $MIN_PROC; j <= $MAX_PROC ; j*=4 )); do

    cd $curdir/node${j}
    filename=run.sh

    for (( r = 0 ; r <= $REPEAT ; r+=1 )); do
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
done

