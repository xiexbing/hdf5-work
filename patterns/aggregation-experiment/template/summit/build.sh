#!/bin/bash


nodes="4"
user=bing

repetitions=9
per_write=3

cdir=/ccs/home/bing/hdf5/ior-aggregation/patterns/benchmark_pattern
machine=summit
idir=$cdir/$machine
#determine how many jobs in the queue
count=`bjobs|grep $user|grep IOR|wc -l`
curr_dir=`pwd`
num_running_jobs=7



node(){
    local node=$1
    ndir=node${node}
    pdir=$idir/$ndir
    
    #delete the echo line in template script
    delete(){
        local t=$1
        if [[ -f $pdir/$t ]]; then
            sed -i "/echo/d" $pdir/$t
        fi
    }
    for t in `ls $pdir`; do
        delete $t
    done


    mkdir -p $ndir
    cp -rf $pdir/hints $ndir/.
    cp template.sh $ndir/.
    touch $ndir/complete

    patterns=`ls $pdir|sed "s/hints//"`   
    cd $ndir

    #check completed pattern
    complete=`cat complete|wc -l`

    pattern(){
        local per=$1
        core=`echo $per | cut -d'_' -f 2`
        size=`echo $per | cut -d'_' -f 3`
        CDIR=ior_data/ior_${core}_${size}
 
        if [[ $count -lt $num_running_jobs ]]; then
            local total_count=0
            local read_count=0
            check_complete(){
                local i=$1
                local record=`sed -n ${i}p complete`
                setting="${core}_${size}"
                total_line=$setting
                read_line="${setting} r"
                echo "$total_line, $record"
                if [[ $record == *"$total_line"* ]]; then
                    total_count=$(($total_count+1)) 
                fi

                if [[ $record == *"$read_line"* ]]; then
                    read_count=$(($read_count+1)) 
                fi
            }
            for i in $(seq 1 1 $complete); do
                check_complete $i
            done

            write_count=$((($total_count-$read_count)*$per_write))
            echo "write count $write_count; read count $read_count"

            if [[ $write_count -lt $repetitions || $read_count -lt $repetitions ]]; then
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
                else
                    sed -i "s/##BSUB/#BSUB/g" ${name}
                    sed -i "s/PREVJOBID/${last}/g" ${name}
                    echo "Submitting $per in node${node}"
                    bsub ${name}
                    count=$(($count+1))
                fi
            fi

            if [[ $write_count -ge $repetitions && $read_count -ge $repetitions ]]; then
                if [[ -d $CDIR ]]; then
                    rm -rf $CDIR
                fi
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
