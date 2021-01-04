dirs=`ls  |grep node`

delete(){
    local dir=$1
    result_dir=`ls $dir|grep "result"`
    rm *_r
    dr(){
        local rrdir=$1
        rm $dir/$rrdir/*_r
    }
    for rrdir in $result_dir; do
        dr $rrdir
    done   
}
for dir in $dirs; do
    delete $dir
done
