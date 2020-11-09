#!/bin/bash

cdir=~/hdf5-work/patterns/aggregation-experiment/patterns/benchmark_pattern/
machine=cori
idir=$cdir/$machine


nodes="4"
curr_dir=`pwd`

first_submit=1
node(){
    local node=$1
    ndir=node${node}
    pdir=$idir/$ndir
    mkdir -p $ndir
    cp -rf $pdir/hints $ndir/.
    cp template.sh $ndir/.

    patterns=`ls $pdir|sed "s/hints//"`   
    cd $ndir
    pattern(){
        local per=$1
        local timestamp=`date +%s`
        local name=${per}_${timestamp}.sh

        cp template.sh $name
        cat $pdir/$per>>$name
        # echo "rm -rf /tmp/jsm.login1.4069">>${name}
        sed -i -e "s/NNODE/$node/g" ${name}

        if [[ $first_submit == 1 ]]; then
            # Submit first job w/o dependency
            echo "Submitting $name"
            first_submit=0
            job=`sbatch $name`
        else
            echo "Submitting $name after ${job: -8}"
            job=`sbatch -d afterany:${job: -8} $name`
        fi
 
    }   
    for per in $patterns; do
        pattern $per
    done
 
}
for node in $nodes; do
    node $node
done

cd $curr_dir
