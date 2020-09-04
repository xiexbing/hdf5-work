#!/bin/bash
START=2
END=128
idir=../insufficient/cori/baseline

for (( i = $START; i <= $END; i*=4 )); do
    mkdir -p ./node${i}
    myfile=./node${i}/run.sh

    cp ./template.sh $myfile
    cat $idir/node${i} >>$myfile
    echo "done">>$myfile
    # echo "rm -rf /tmp/jsm.$(hostname).4069">>$myfile
    sed -i "s/NNODE/$i/g" $myfile 
    chmod a+rwx $myfile
    
    # sed -i "s/ITER/20/g" $myfile 

    # myfile=./${i}node/run1.sh
    # cp ./template.sh $myfile
    # sed -i "s/NNODE/$i/g" $myfile 
    # sed -i "s/ITER/1/g" $myfile 
done
