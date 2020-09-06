#!/bin/bash -l

curr_dir=`pwd`
data_dir=/darshan/hdf5
darshan_dir=/darshan/summit
exps="summit_baseline summit_blocks summit_collective"
IDs=""


rm curr_*
rm e.* o.*
rm complete running

exp_process(){
    local exp=$1
    exp_dir=$data_dir/$exp
    rm -rf $exp_dir/darshan
}
for exp in $exps; do
    exp_process $exp
done

echo "clean done"
