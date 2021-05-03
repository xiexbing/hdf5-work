import os
import numpy as np
import shutil
import math


machines = ['summit', 'cori', 'theta']
nodes = [4, 8, 16, 32]
per_set = 2
# per_set = 20
rdir = "benchmark_pattern_noindep"

def generate_pattern():

    for machine in machines:
        for node in nodes:
            sizeGroups = generate_sizes(machine) 
            nodeSizes = []

            for p, sizeSum in enumerate(sizeGroups):
                [sizeGroup, sizeRange, sizeName] = sizeSum
                [sizeMin, sizeMax] = sizeRange 
                print (machine, node, sizeName)
                for i, size in enumerate(sizeGroup):
                    confirm = 0
                    while confirm == 0:
                        if machine == 'summit':                    
                            core = np.random.randint(1, 42, 1)[0]
                        elif machine == 'cori':                    
                            core = np.random.randint(1, 32, 1)[0]
                        elif machine == 'theta':                    
                            core = np.random.randint(1, 64, 1)[0]


                        #data size per core
                        per_size = int(math.ceil(size/core))
                        node_size = per_size *core
                        if p <6: 
                            if node_size >= sizeMin and node_size <= sizeMax and node_size not in nodeSizes and per_size < 1024*1024:
                                nodeSizes.append(node_size)
                                per_pattern(machine, sizeName, node, core, per_size)
                                confirm = 1
                        else:
                            if node_size >= sizeMin and node_size <= sizeMax and node_size not in nodeSizes:
                                nodeSizes.append(node_size)
                                per_pattern(machine, sizeName, node, core, per_size)
                                confirm = 1
 

            generate_hints(machine, node)    

def generate_hints(machine, node):

    hdir = rdir + '/' + machine + '/node' + str(node) + '/hints'
    naggrs = [int(node*4), int(node*2), int(node), int(node/2), int(node/4)]
    buffSizes = [1, 4, 16, 64, 256]
    indep_rw = ['true', 'false'] 
    unit = 1024*1024

    #config list
    if not os.path.isdir(hdir):
        os.makedirs(hdir)
    for n in naggrs:
        aggr = str(n)
        if n > node:
            per = int(n/node)
        else:
            per = 1

        for indep in indep_rw:
            if machine == 'summit':
                for size in buffSizes:
                    bsize = str(size * unit)
                    aggrLine = 'cb_nodes ' + aggr + '\n'
                    sizeLine = 'cb_buffer_size ' + bsize + '\n'
                    wLine = 'romio_cb_write enable' + '\n'
                    rLine = 'romio_cb_read enable' + '\n'
                    listLine = 'cb_config_list ' + '*:' + str(per) + '\n'
                    indepLine = 'romio_no_indep_rw ' + indep + '\n'
                    name = 'aggr_' + aggr + '_' + str(size) + 'M' + '_noindep' + indep
                    f = os.path.join(hdir, name)
                    hf = open(f, 'a')
                    hf.write(aggrLine)
                    hf.write(sizeLine)
                    hf.write(wLine)
                    hf.write(rLine)
                    hf.write(listLine)
                    hf.write(indepLine)
                    hf.truncate()
                    hf.close() 

            if machine == 'cori' or machine == 'theta':
                aggrLine = 'cb_nodes=' + aggr + ':'
    #           sizeLine = 'cb_buffer_size=' + bsize + ':'
                wLine = 'romio_cb_write=enable' + ':'
                rLine = 'romio_cb_read=enable' + ':'
                listLine = 'cb_config_list=' + '#*:' + str(per) + '\n'
     
                name = 'aggr_' + aggr 
                f = os.path.join(hdir, name)
                hf = open(f, 'a')
                hf.write(aggrLine)
    #           hf.write(sizeLine)
                hf.write(wLine)
                hf.write(rLine)
                hf.write(listLine)
                hf.truncate()
                hf.close() 


    aggrLine = 'cb_nodes ' + str(node) + '\n'
    sizeLine = 'cb_buffer_size 16777216' + '\n'
    wLine = 'romio_cb_write automatic' + '\n'
    rLine = 'romio_cb_read automatic' + '\n'
    name = 'default' 
    f = os.path.join(hdir, name)
    hf = open(f, 'a')
    hf.write(aggrLine)
    hf.write(sizeLine)
    hf.write(wLine)
    hf.write(rLine)
    hf.truncate()
    hf.close()

                        
def generate_sizes(machine):

    #aggregate size per node 1KB --- 4MB (4096KB) 
    n1 = np.random.randint(1, 4*1024, per_set)

    # #aggregate size per node 4097KB --- 16MB (16*1024KB) 
    # n2 = np.random.randint(4*1024+1, 16*1024, per_set)

    # #aggregate size per node 16*1024+1 KB --- 64MB (64*1024KB)
    # n3 = np.random.randint(16*1024+1, 64*1024, per_set)

    # #aggregate size per node 64*1024+1 KB --- 256MB (256*1024KB) 
    # n4 = np.random.randint(64*1024+1, 256*1024, per_set)

    # #aggregate size per node 256*1024+1 KB --- 1GB (1024*1024KB) 
    # n5 = np.random.randint(256*1024+1, 1024*1024, per_set)

    # #aggregate size per node 1024*1024+1 KB --- 4GB (4*1024*1024KB) 
    # n6 = np.random.randint(1024*1024+1, 4*1024*1024, per_set)

    # #aggregate size per node 1024*1024+1 KB --- 4GB (4*1024*1024KB) 
    # n6 = np.random.randint(1024*1024+1, 4*1024*1024, per_set)

    # #aggregate size per node 4*1024*1024+1 KB --- 60GB (60*1024*1024KB) 
    # if machine == 'summit':
    #     n7 = np.random.randint(4*1024*1024+1, 60*1024*1024, per_set)
    # elif machine == 'theta':
    #     n7 = np.random.randint(4*1024*1024+1, 20*1024*1024, per_set)
    # elif machine == 'cori':
    #     n7 = np.random.randint(4*1024*1024+1, 13*1024*1024, per_set)




    if machine == 'summit':
        node_sizes = [[n1, [1, 4*1024], 'n1']]
# , [n2, [4*1024+1, 16*1024], 'n2'],  [n3, [16*1024+1, 64*1024], 'n3'],  [n4, [64*1024+1, 256*1024], 'n4'],  [n5, [256*1024+1, 1024*1024], 'n5'],  [n6, [1024*1024+1, 4*1024*1024], 'n6'], [n7, [4*1024*1024+1, 60*1024*1024], 'n7']
    elif machine == 'theta':
        node_sizes = [[n1, [1, 4*1024], 'n1']]
# , [n2, [4*1024+1, 16*1024], 'n2'],  [n3, [16*1024+1, 64*1024], 'n3'],  [n4, [64*1024+1, 256*1024], 'n4'],  [n5, [256*1024+1, 1024*1024], 'n5'],  [n6, [1024*1024+1, 4*1024*1024], 'n6'], [n7, [4*1024*1024+1, 20*1024*1024], 'n7']
    elif machine == 'cori':
        node_sizes = [[n1, [1, 4*1024], 'n1']]
# , [n2, [4*1024+1, 16*1024], 'n2'],  [n3, [16*1024+1, 64*1024], 'n3'],  [n4, [64*1024+1, 256*1024], 'n4'],  [n5, [256*1024+1, 1024*1024], 'n5'],  [n6, [1024*1024+1, 4*1024*1024], 'n6'], [n7, [4*1024*1024+1, 13*1024*1024], 'n7']



    return node_sizes

def per_pattern(machine, sizeName, node, core, per_size):

    name = sizeName + "_" + str(core) + "_" + str(per_size) + "k"
    ndir = rdir + '/' + machine + '/node' + str(node) 
    
    if not os.path.isdir(ndir):
        os.makedirs(ndir)
    fname = os.path.join(ndir, name) 
    ffile = open(fname, 'a')

    iline = '\n' + "for i in $(seq 1 1 1); do" + '\n'
    score = "'" + str(core) + "'"
    coreline = "for ncore in " + score + "; do" + '\n'
    ssize = "'" + str(per_size) + "k" + "'"
    sizeline = "for burst in " + ssize + "; do" + '\n'
#    stripeLine = "for stripe_size in $stripe_sizes; do" + '\n'

    iorline = "ior $i $ncore $burst" + '\n'
    coriline = "ior $i $ncore $burst" + '\n'


    doneline = "done" + '\n'
#    recordline = "echo " + name +">>complete" + '\n'
    ffile.write(iline)
    ffile.write(coreline)
    ffile.write(sizeline)
#    if machine == 'cori' or machine == 'theta':
#        ffile.write(stripeLine)
    if machine == 'summit':
        ffile.write(iorline)
    else:
        ffile.write(coriline)
    ffile.write(doneline)
    ffile.write(doneline)
    ffile.write(doneline)
#    if machine == 'cori' or machine == 'theta':
#        ffile.write(doneline)
#    ffile.write(recordline)

         

def main():

    if os.path.isdir(rdir):
        shutil.rmtree(rdir)

    generate_pattern()

main()

