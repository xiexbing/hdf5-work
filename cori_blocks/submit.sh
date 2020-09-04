#!/bin/bash

MIN_PROC=128
MAX_PROC=128
REPEAT=4

curdir=$(pwd)
# ./gen.sh

first_submit=1
for (( j = $MIN_PROC; j <= $MAX_PROC ; j*=4 )); do
    for (( i = 0; i < REPEAT; i++ )); do

        cd $curdir/node${j}
        filename=run.sh

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

