#!/bin/bash


nodes="4"
user=bing
num_running_jobs=20




cdir=/ccs/home/bing/hdf5/ior_aggregation/patterns/benchmark_pattern
machine=summit
idir=$cdir/$machine
#determine how many jobs in the queue
count=`bjobs|grep $user|wc -l`
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

    #check completed pattern
    complete=`cat complete`

    pattern(){
        local per=$1
        local num=0
        check_complete(){
            local record=$1
            if [[ "$record" == "$per" ]]; then
                num=$(($num + 1)) 
            fi
        }
        for record in $complete; do
            check_complete $record
        done

        if [[ $num -lt 3 ]]; then
            local timestamp=`date +%s`
            local name=${per}_${timestamp}.sh

            cp template.sh $name
            cat $pdir/$per>>$name
            echo "rm -rf /tmp/jsm.login1.4069">>${name}
            sed -i -e "s/NNODE/$node/g" ${name}

            last=`bjobs|grep $user|grep "IOR"|tail -1|awk '{print $1}'`
            if [[ -z $last ]]; then
                echo "Submitting $per in node${node}"
                bsub ${name}
                count=$(($count+1))
            elif [[ $count -lt $num_running_jobs ]]; then
                sed -i "s/##BSUB/#BSUB/g" ${name}
                sed -i "s/PREVJOBID/${last}/g" ${name}
                echo "Submitting $per in node${node}"
                bsub ${name}
                count=$(($count+1))
            fi
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
