#!/bin/bash
i=0
while [ true ];
do
    echo "Submission $i"
    ./test.sh
    ./build.sh
    date

    sleep 3000

    let i+=1
done
