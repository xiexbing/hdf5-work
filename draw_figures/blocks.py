import os
import matplotlib as mpl
if os.environ.get('DISPLAY','') == '':
    mpl.use('Agg')
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import shutil
from matplotlib import cm

machines = ["summit"]
rdir = "hdf5/data"
nodes = [2, 8, 32, 128]

def read_file(data_file):
    d_f = open(data_file, 'r')
    dfile = d_f.readlines()
    d_f.close()

    return dfile

def print_box(exp, n, data):

   apis = ["POSIX", "MPIIO", "HDF5", "HDF51m", "HDF54m", "HDF516m", "HDF564m", "HDF5256m"]
   sizes= ["16k", "256k", "16m", "256m", "1024m"]
   l = ['POSIX', 'MPIIO', 'H-D', 'H-1MB', 'H-4MB', 'H-16MB', 'H-64MB', 'H-256MB']

   rw = ['f', 'r']
   #draw figure
   start = 0.85
   stop = 0.15
   cm_subsection = np.linspace(start, stop, 3)
   colors = [cm.coolwarm(x) for x in cm_subsection]
   blocks = [4, 8, 16]

   if exp == "blocks":
       for psize in sizes:
           for op in rw:
               data_sum = []
               pos = []
               cs = []
               ll = []
               for i, papi in enumerate(apis):
                   api_pos = i+1
                   for j, block in enumerate(blocks):
                       cpos = api_pos + (j+1)*0.2
                       cs.append(colors[j])
                       for per in data:
                           [rname, per_data] = per
                           inform = rname.split("_")
                           api = inform[0]
                           asize = inform[1]
                           cores = int(inform[2])
                           ablock = int(inform[3])
                           arw = inform[4]
                           if asize == psize and papi == api and op == arw and block == ablock: 
                               data_sum.append(per_data)
                               pos.append(cpos)
                               if j%3 == 1:
                                   ll.append(l[i])
                               else:
                                   ll.append("") 
               bplot = plt.boxplot(data_sum, widths=0.2, positions=pos, notch='True',patch_artist=True, labels=ll)

               for b in bplot:
                   for patch, color in zip(bplot['boxes'], cs):
                       patch.set_facecolor(color)

               plt.ylabel("Aggregate Bandwidth, Unit:GB/s", fontsize=12)
               plt.xlabel("I/O APIs Used for Write System Calls", fontsize=12)
               plt.rc('xtick', labelsize=11) 
               plt.rc('ytick', labelsize=12) 
               plt.legend([bplot["boxes"][0], bplot["boxes"][1], bplot["boxes"][2]], ['4 blocks', '8 blocks', '16 blocks'], loc='upper right')
               if psize == '16k':
                   plt.ylim(0, 0.01)
               elif psize == '256k':
                   plt.ylim(0, 0.1)
               elif psize == '1024m':
                   plt.ylim(0, 300)



               Name = exp + "_" + n + "_" + psize + "_" + op + ".pdf"
               Name = os.path.join(exp, Name)
               plt.savefig(Name)
               plt.close()  


def print_cdf(data):

    nnames = ["node128"]
    apis = ['HDF5', 'HDF51m', 'HDF54m', 'HDF516m', 'HDF564m', 'HDF5256m']
    asizes = ['16k', '256k', '16m', '256m', '1024m']
    blocks = ['4', '8', '16']
    start = 0
    stop = 1 
    cm_subsection = np.linspace(start, stop, 6)
    colors = [cm.Spectral(x) for x in cm_subsection]
    
    result = []
    max_now = 3.0
    for n in nnames:
        for asize in asizes:
            for block in blocks:
                plt.figure()
                l = 0
                for api in apis:
                    print (n, asize, api, block)
                    api_sum = []
                    for per in data:
                        [exp, nexp, setting, dfile, dinform] = per   
                        inform = setting.split('_')
                        papi = inform[0]
                        psize = inform[1]
                        pblock = inform[3]
                        if n == nexp and asize == psize and api == papi and block == pblock and 'f' in setting:
                            for time in dinform:
                                api_sum.append(time)

                    steps = 100
                    step = max_now/steps
                    x = []
                    api_cdf = []
                    for i in range(steps):
                        now = step*(i+1)
                        count = sum(j <= now for j in api_sum) /float(len(api_sum))
                        api_cdf.append(count)
                        x.append(now)
                    line = api.replace("HDF5", 'alignment value ')
                    plt.plot(x, api_cdf, linewidth =2, color = colors[l], label = line)
                    l += 1
                plt.legend(loc='lower right')
                plt.xlim(0, max_now)
                plt.ylim(0, 1)
                plt.ylabel("CDF")
                plt.xlabel("Write Time, Unit:Second")
                Name = "blocks/" +n + "_" + asize + "_" +block + ".pdf"
                plt.savefig(Name)
                plt.close() 
 
def collect_data(mdir):
     
    if os.path.isdir("blocks"):
        shutil.rmtree("blocks")
    os.mkdir("blocks")

    time_sum = []
    for exp in os.listdir(mdir):
        if exp == "blocks":
            edir = os.path.join(mdir, exp)
            for nnode in os.listdir(edir):
                ndir = os.path.join(edir, nnode)
                for setting in os.listdir(ndir):
                    sdir = os.path.join(ndir, setting + "/darshan")
                    for dfile in os.listdir(sdir):
                        if "block" in dfile:
                            df = os.path.join(sdir, dfile)
                            dinform = read_file(df)
                            for i, line in enumerate(dinform):
                                dinform[i] = float(line.split()[0])
                            per = [exp, nnode, setting, dfile, dinform]
                            time_sum.append(per)

    print_cdf(time_sum)



def main():
    for machine in machines:
        mdir = os.path.join(rdir, machine)
        collect_data(mdir) 

main()
