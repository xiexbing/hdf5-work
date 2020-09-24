jobs=`ls experiment`

delete(){
    local job=$1
    rm -rf experiment/$job/darshan/block*
}
for job in $jobs; do
    delete $job
done
