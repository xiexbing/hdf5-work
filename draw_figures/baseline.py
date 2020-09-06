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
rdir = "darshan/fast/data"
nodes = [2, 8, 32, 128]

def read_file(data_file):
    d_f = open(data_file, 'r')
    dfile = d_f.readlines()
    d_f.close()

    return dfile

def print_box(exp, n, data):

   apis = ["POSIX", "MPIIO", "HDF5", "HDF5C", "HDF51m", "HDF51mC", "HDF54m", "HDF54mC", "HDF516m", "HDF516mC", "HDF564m", "HDF564mC", "HDF5256m", "HDF5256mC"]
   apis = ["POSIX", "MPIIO", "HDF5", "HDF51m", "HDF54m", "HDF516m", "HDF564m", "HDF5256m"]
   sizes= ["1k", "16k", "256k", "1m", "16m", "256m", "1g"]
   l = ['POSIX', 'MPIIO', 'HD',  'H1M', 'H4M', 'H16M', 'H64M', 'H256M']
   rw = ['f', 'r']
   start = 0.15
   stop = 0.15
   cm_subsection = np.linspace(start, stop, 1)
   colors = [cm.coolwarm(x) for x in cm_subsection]
   blocks = [4, 8, 16]
   cs = []

   if exp == "baseline":
       for psize in sizes:
           for op in rw:
               data_sum = []
               ll = 1000
               for papi in apis:
                   cs.append(colors[0])
                   for per in data:
                       [rname, per_data] = per
                       inform = rname.split("_")
                       api = inform[0]
                       asize = inform[1]
                       cores = int(inform[2])
                       blocks = int(inform[3])
                       arw = inform[4] 
                       if asize == psize and papi == api and op == arw: 
                           data_sum.append(per_data)
               bplot = plt.boxplot(data_sum, notch='True',patch_artist=True, labels=l)
               plt.ylabel("Aggregate Bandwidth, Unit:GB/s", fontsize=12)
               plt.xlabel("I/O APIs Used for Write System Calls", fontsize=12)
               plt.rc('xtick', labelsize=11) 
               plt.rc('ytick', labelsize=12) 
               if psize == '16k' and op == 'f':
                   plt.ylim(0, 0.01)
               elif psize == '256k' and op == 'f':
                   plt.ylim(0, 0.1)
               elif psize == '1m' and op == 'f':
                   plt.ylim(0, 0.1)
               elif psize == '1g' and op == 'f':
                   plt.ylim(0, 300)




               for b in bplot:
                   for patch, color in zip(bplot['boxes'], cs):
                       patch.set_facecolor(color)

               Name = exp + "_" + n + "_" + psize + "_" + op + ".pdf"
               Name = os.path.join(exp, Name)
               plt.savefig(Name)
               plt.close()  

def collect_data(mdir):
    
    for exp in os.listdir(mdir):
        if os.path.isdir(exp):
            shutil.rmtree(exp)
        os.mkdir(exp)

        edir = os.path.join(mdir, exp)
        for nexp in os.listdir(edir):
            data = []
            ndir = os.path.join(edir, nexp)
            for setting in os.listdir(ndir):
                sdir = os.path.join(ndir, setting)
                band_dir = os.path.join(sdir, "aggregate-bandwidth")
                band_inform = read_file(band_dir)
                for i, per in enumerate(band_inform):
                    band_inform[i] = float(band_inform[i].split()[0])
                data.append([setting, band_inform])
                    
            print_box(exp, nexp, data)
def main():
    for machine in machines:
        mdir = os.path.join(rdir, machine)
        collect_data(mdir) 

main()
