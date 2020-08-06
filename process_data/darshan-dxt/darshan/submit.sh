#!/bin/bash -l

curr_dir=`pwd`
data_dir=$ior_result_dir
exps="summit_baseline summit_blocks summit_collective"
IDs=""
count=`squeue -u bing|grep bing|wc -l`


rm curr_*
touch complete
touch running
exp_process(){
    local exp=$1
    exp_dir=$data_dir/$exp
    group_process(){
        local group=$1
        group_dir=$exp_dir/$group
        if [[ -d $group_dir && $group != "darshan" ]]; then
            nnames=`ls $group_dir`
        fi
        node_process(){
            local node=$1
            if [[ -d $group_dir && $group != "darshan" && $group != *"node"* ]]; then
                ndir=$group_dir/$node
                cd $ndir
                jobs=`ls o*.*`
                cd $curr_dir
                job_process(){
                    job=$1
                    job_name=$(echo $job | cut -d'.' -f 1)
                    job_name=`echo $job_name|sed 's/o/id/g'`
                    job_dir=$ndir/$job
                    start_time=`cat $job_dir|grep "Started at"|sed 's/Started at//'`
                    start_date=`date -d "${start_time}" +%F`
                    year=$(echo $start_date | cut -d'-' -f 1)
                    month=$(echo $start_date | cut -d'-' -f 2)
                    mon1=`echo "$month" | cut -c1`
                    if [[ $mon1 == "0" ]]; then
                        month=$(echo $month|sed 's/0//')
                    fi
                    day=$(echo $start_date | cut -d'-' -f 3)
                    day1=`echo "$day" | cut -c1`
                    if [[ $day1 == "0" ]]; then
                        day=$(echo $day|sed 's/0//')
                    fi
                    end_time=`cat $job_dir|grep "Terminated at"|sed 's/Terminated at//'`
                    end_date=`date -d "${end_time}" +%F`
   
                    TIME=${month}_${day}
                    current=`date +%s`
                    complete_line=`echo "${job_name} $TIME"`
                    if [[ `cat complete` != *"${complete_line}"* && `cat running` != *"${complete_line}"* && $count -lt 80 ]]; then
                        cp summit.template curr_${current}
                        if [[ $count -gt 40 ]]; then
                            prev=`echo "$IDs" | awk -F "_" '{print $1}'`
                            sed -i -e "s/##BSUB/#BSUB/g" -e "s/PREV/${prev}/g" curr_${current}
                            prev=${prev}_
                            IDs=${IDs//$prev/}
                        fi
                        sed -i -e "s/TIME/${TIME}/g" -e "s/IDs/${job_name}/g" -e "s/EXP/$exp/g" curr_${current} 
                        job=`sbatch curr_${current}`
                        echo "${complete_line}">>running
                        ID=`echo $job|awk '{print $4}'`
                        IDs=`echo ${IDs}${ID}_`
                        count=$(($count+1))
                        echo "running new job $complete_line in $job and $exp"
                    elif [[ `cat complete` == *"${complete_line}"* ]]; then
                        echo "${complete_line} done"
                    elif [[ `cat running` == *"${complete_line}"* ]]; then
                        echo "${complete_line} is running"
                    elif [[ $count -ge 80 ]]; then
                        echo "$count >= 80"
                    fi
                    if [[ "$start_date" != "$end_date" ]]; then
                        year=$(echo $end_date | cut -d'-' -f 1)
                        month=$(echo $end_date | cut -d'-' -f 2|sed 's/0//')
                        mon1=`echo "$month" | cut -c1`
                        if [[ $mon1 == "0" ]]; then
                            month=$(echo $month|sed 's/0//')
                        fi
                        day=$(echo $end_date | cut -d'-' -f 3)
                        day1=`echo "$day" | cut -c1`
                        if [[ $day1 == "0" ]]; then
                            day=$(echo $day|sed 's/0//')
                        fi
                        TIME=${month}_${day}
                        current=`date +%s`

                        if [[ `cat complete` != *"${complete_line}"* && `cat running` != *"${complete_line}"* && $count -lt 80 ]]; then
 
                            cp summit.template curr_${current}
                            if [[ $count -gt 40 ]]; then
                                prev=`echo "$IDs" | awk -F "_" '{print $1}'`
                                sed -i -e "s/##BSUB/#BSUB/g" -e "s/PREV/${prev}/g" curr_${current}
                                prev=${prev}_
                                IDs=${IDs//$prev/}
                            fi
                            sed -i -e "s/TIME/${TIME}/g" -e "s/IDs/${job_name}/g" -e "s/EXP/$exp/g" curr_${current} 
                            job=`sbatch curr_${current}`
                            echo "$complete_line">>running
                            ID=`echo $job|awk '{print $4}'`
                            IDs=`echo ${IDs}${ID}_`
                            count=$(($count+1))
                            echo "running new job $complete_line in $job and $exp"
                        elif [[ `cat complete` == *"${job_name}"* ]]; then
                            echo "${complete_line} done"
                        elif [[ `cat running` == *"${complete_line}"* ]]; then
                            echo "${complete_line} is running"
                        elif [[ $count -ge 80 ]]; then
                            echo "$count >= 80"

                        fi
                    fi
 

                    echo $job_name
                }
                for job in $jobs; do
                    job_process $job
                done
                 
            fi
        }
        for node in $nnames; do
            node_process $node
        done
    }
    for group in `ls $exp_dir`; do
        group_process $group
    done
}
for exp in $exps; do
    exp_process $exp
done
