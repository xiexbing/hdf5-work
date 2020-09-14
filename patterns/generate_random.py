import os
import numpy as np
import shutil
import math

nodes = 512

def generate_pattern():
   
    filesizes = generate_sizes() 

    for machine in ['summit', 'cori']:
        for gsize in filesizes:
            [fsize, gname] = gsize
            for i, size in enumerate(fsize):
                confirm = 0
                while confirm == 0:
                    if gname != 'g4':
                       core = np.random.randint(1, 16, 1)[0]
                       dataset = np.random.randint(1, 200, 1)[0]
                    else:
                       core = np.random.randint(1, 4, 1)[0]
                       dataset = np.random.randint(1, 40, 1)[0]
 

                    if nodes * core * dataset <= size:
                         
                        per_size = size/500/core/dataset
                        #is it kb
                        if per_size > 1:
                            #is it mb
                            if per_size/1024 > 1:
                                per_size = math.ceil(per_size/1024)
                                per_size = str(per_size) + 'm'
 
                            else:
                                per_size = str(math.ceil(per_size)) + 'k' 
                        else:
                            per_size = '1k'
 
                        confirm = 1 
                per_pattern(machine, per_size, core, dataset, gname, i)



def generate_sizes():

    #aggregate size 512MB --- 1GB 
    g1 = np.random.randint(512*1024, 1024*1024, 50)

    #aggregate size 1GB --- 10GB 
    g2 = np.random.randint(1024*1024, 10*1024*1024, 50)

    #aggregate size 10GB --- 100GB 
    g3 = np.random.randint(10*1024*1024, 100*1024*1024, 50)

    #aggregate size 100GB --- 2TB 
    g4 = np.random.randint(100*1024*1024, 2*1024*1024*1024, 50)

    return [[g1,'g1'], [g2,'g2'], [g3,'g3'], [g4, 'g4']]

def per_pattern(machine, size, core, dataset, gname, j):

    if j < 25:
        d = 'f1'
    else:
        d = 'f2'

    
    fdir = d + '/' + machine
    if not os.path.isdir(fdir):
        os.makedirs(fdir)
    fname = fdir + '/' + gname + "_" + size + "_" + str(core) + "_" + str(dataset)
    ffile = open(fname, 'a') 

    iline = '\n' + "for i in $(seq 1 1 3); do" + '\n'           
    sgroup = "'" + gname + "'"
    groupline = "for group in " + sgroup + "; do" + '\n'  
    ssize = "'" + size + "'"   
    sizeline = "for size in " + ssize + "; do" + '\n'  
    score = "'" + str(core) + "'"  
    coreline = "for core in " + score + "; do" + '\n'  
    sdataset = "'" + str(dataset) + "'"  
    datasetline = "for dataset in " + sdataset + "; do" + '\n'  
    iorline = "per $i $group $size $core $dataset" + '\n'  
    doneline = "done" + '\n'  
    recordline = "echo " + gname + "_" + size + "_" + str(core) + "_" + str(dataset) + " done" + '\n'

    if machine == 'summit':
        ffile.write(iline)
        ffile.write(sizeline)
        ffile.write(coreline)
        ffile.write(datasetline)
        ffile.write(iorline)
        ffile.write(doneline)
        ffile.write(doneline)
        ffile.write(doneline)
        ffile.write(doneline)
        ffile.write(recordline)
    elif machine == 'cori':
        ffile.write(iline)
        ffile.write(groupline)
        ffile.write(sizeline)
        ffile.write(coreline)
        ffile.write(datasetline)
        ffile.write(iorline)
        ffile.write(doneline)
        ffile.write(doneline)
        ffile.write(doneline)
        ffile.write(doneline)
        ffile.write(doneline)
        ffile.write(recordline)
        


def main():

    dirs = ["f1", "f2"]
      
    for d in dirs: 
        if  os.path.isdir(d):
            shutil.rmtree(d)

    generate_pattern()

main()

