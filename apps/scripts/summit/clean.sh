#!/bin/bash

nnode=512
nnode=2


CASES=("vpicio" "bdcatsio" "amrex_single" "amrex_multi" )
curdir=$(pwd)

for mycase in "${CASES[@]}"
do

    cd $curdir/${mycase}/${nnode}node
    mkdir -p achieve
    mv ./o* achieve/
    rm ./*.sh
done

