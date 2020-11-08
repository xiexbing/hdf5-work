#!/bin/bash

cdir=/ccs/home/bing/hdf5/ior_aggregation/patterns/benchmark_pattern
machine=summit
idir=$cdir/$machine


nodes="4"
curr_dir=`pwd`

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
        sed -i -e "s/NNODE/$node/g" ${name}

        last=`bjobs|grep "IOR"|tail -1|awk '{print $1}'`
        if [[ -z $last ]]; then
            echo "Submitting $per in node${node}"
            bsub ${name}
        else
            sed -i "s/##BSUB/#BSUB/g" ${name}
            sed -i "s/PREVJOBID/${last}/g" ${name}
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
