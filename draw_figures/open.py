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
rdir = "/hdf5/data"
nodes = [2, 8, 32, 128]

def read_file(data_file):
    d_f = open(data_file, 'r')
    dfile = d_f.readlines()
    d_f.close()

    return dfile

def print_box(exp, n, data):

   apis = ["POSIX", "MPIIO", "HDF5", "HDF5C", "HDF51m", "HDF51mC", "HDF54m", "HDF54mC", "HDF516m","HDF516mC", "HDF564m", "HDF564mC", "HDF5256m", "HDF5256mC"]
   sizes= ["16k", "256k", "16m", "256m", "1024m"]
   l = ['P', 'M', 'D', 'CD',  '1','C1',  '4', 'C4', '16', 'C16', '64', 'C64', '256', 'C256']

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
               print (len(ll), len(data_sum), psize)
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

    [open_sum, close_sum] = data
    nnames = ["node2", "node8", "node32", "node128"]
    apis = ['POSIX', 'MPIIO', 'HDF5']
    rw = ['f', 'r']

    start = 0
    stop = 1 
    cm_subsection = np.linspace(start, stop, 12)
    colors = [cm.Spectral(x) for x in cm_subsection]

    open_times = []
    close_times = []
    open_max = []
    close_max = []

    for op in rw:
        for n in nnames:
            for api in apis:
                api_sum = [n, api, op, []]
                for per in  open_sum:
                    [nname, setting, data] = per
                    if api in setting and n == nname and op in setting:
                        for time in data:
                            api_sum[3].append(time)
                            open_max.append(time)      
                open_times.append(api_sum)        

                capi_sum = [n, api, op, []]
                for per in  close_sum:
                    [nname, setting, data] = per
                    if api in setting and n == nname and op in setting:
                        for time in data:
                            capi_sum[3].append(time)
                            close_max.append(time)      
                close_times.append(capi_sum)        
                    
 #   o_max = np.percentile(open_max, 99)       
 #   c_max = np.percentile(close_max, 99)       
    o_max = 4       
    c_max = 4    


    plt.figure()
    steps = 100
    step = o_max/steps

    for op in rw:
        l = 0
        for api in apis:
            for n in nnames:
                for api_sum in open_times:
                    [nname, papi, pop, data] = api_sum
                    if n == nname and op == pop and api == papi:
                        x = []
                        data_cdf = []
                        for i in range(steps):
                            now = step*(i+1)
                            count = sum(j <= now for j in data) /float(len(data))
                            data_cdf.append(count)
                            x.append(now)
                        line = papi + "_" + n
                        plt.plot(x, data_cdf, linewidth =2, color = colors[l], label = line)
                        l += 1
        plt.legend()
        plt.xlim(0, o_max)
        plt.ylim(0, 1)
        plt.ylabel("CDF")
        plt.xlabel("File Open Time, Unit:Second")



        Name = "open/open_" + op + ".pdf"
        plt.savefig(Name)
        plt.close()
 
    for op in rw:
        l = 0
        for api in apis:
            for n in nnames:
                for api_sum in close_times:
                    [nname, papi, pop, data] = api_sum
                    if n == nname and op == pop and api == papi:
                        x = []
                        data_cdf = []
                        for i in range(steps):
                            now = step*(i+1)
                            count = sum(j <= now for j in data) /float(len(data))
                            data_cdf.append(count)
                            x.append(now)
                        line = papi + "_" + n
                        plt.plot(x, data_cdf, linewidth =2, color = colors[l], label = line)
                        l += 1
        plt.legend()
        plt.xlim(0, c_max)
        plt.ylim(0, 1)
        plt.ylabel("CDF")
        plt.xlabel("File Close Time, Unit:Second")


        Name = "open/close_" + op + ".pdf"
        plt.savefig(Name)
        plt.close()
 
def collect_data(mdir):
     
    if os.path.isdir("open"):
        shutil.rmtree("open")
    os.mkdir("open")

    open_sum = []
    close_sum = []
    for exp in os.listdir(mdir):
        edir = os.path.join(mdir, exp)
        for nexp in os.listdir(edir):
            data = []
            ndir = os.path.join(edir, nexp)
            for setting in os.listdir(ndir):
                sdir = os.path.join(ndir, setting)
                open_dir = os.path.join(sdir, "open")
                open_inform = read_file(open_dir)
                close_dir = os.path.join(sdir, "close")
                close_inform = read_file(close_dir)

                for i, per in enumerate(open_inform):
                    open_inform[i] = float(open_inform[i].split()[0])
                open_sum.append([nexp, setting, open_inform])
                for i, per in enumerate(close_inform):
                    close_inform[i] = float(close_inform[i].split()[0])
                close_sum.append([nexp, setting, close_inform])
                    
    print_cdf([open_sum, close_sum])



def main():
    for machine in machines:
        mdir = os.path.join(rdir, machine)
        collect_data(mdir) 

main()
