node=4
naggr=8
ncore=41

list="cb_config_list "

if [[ $naggr -le $node ]]; then
    ag(){
        local na=$1
        rank=$((($na-1)*$ncore))
        list=$list" $rank"
    }
    for na in $(seq 1 1 $naggr); do
        ag $na
    done
else
    daggr=$node 
    dg(){
        local na=$1
        inNode=$(($naggr/$node))
        per(){
            local p=$1
            n=$((($na-1)*$ncore))
            rank=$(($n+$p-1))
            list=$list" $rank"
        }
        for p in $(seq 1 1 $inNode); do
            per $p
        done 
    }
    for na in $(seq 1 1 $node); do
        dg $na
    done
fi
    
echo $list
