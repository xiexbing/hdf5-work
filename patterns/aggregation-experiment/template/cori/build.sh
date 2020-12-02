#!/bin/bash


nodes="4"
user=houhun
num_running_jobs=30




cdir=~/hdf5-work/patterns/aggregation-experiment/patterns/benchmark_pattern/
machine=cori
idir=$cdir/$machine
#determine how many jobs in the queue
count=`sqs|grep $USER|wc -l`
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
            sed -i -e "s/NNODE/$node/g" ${name}
            echo "echo \"====Done====\"" >> $name
            echo "date" >> $name

            if [[ $first_submit == 1 ]]; then
                # Submit first job w/o dependency
                echo "Submitting $name"
                first_submit=0
                job=`sbatch $name`
            elif [[ $count -lt $num_running_jobs ]]; then
                echo "Submitting $name after ${job: -8}"
                job=`sbatch -d afterany:${job: -8} $name`
            fi
            count=$(($count+1))
 
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
