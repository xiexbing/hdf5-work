#!/bin/bash

node=2
cdir=f1
machine=summit
idir=/ccs/home/bing/hdf5/ior_experiment/patterns/$cdir/$machine

all_patterns=`ls $idir`
complete_records=`ls o*`

date=`date +%s`
cp ${machine}_template.sh submit_${date}.sh

sed -i -e "s/NNODE/$node/g" submit_${date}.sh

check_record(){
    local pattern=$1
    local count=0

    if [[ ! -z $complete_records ]]; then
        check_complete(){
            local record=$1
            n=`cat $record|grep $pattern`
            if [[ ! -z $n ]]; then
                count=$((1+$count))  
            fi
            echo "$record $pattern $n"
        }
        for record in $complete_records; do
            check_complete $record
        done
    fi

    if [[ $count -lt 3 ]]; then
        pdir=$idir/$pattern
        cat $pdir>>submit_${date}.sh
    else
        echo "$pattern is completed"
    fi 
}
for pattern in $all_patterns; do
    check_record $pattern
done
#check_record


bsub submit_${date}.sh
