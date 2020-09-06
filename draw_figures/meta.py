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

   sizes= ["1m", "16m"]
   nsets = ['2', '8', '32',  '128']
   defs = ['0_0_0', '1_0_0', '0_0_1', '1_0_1', '1_1_1']
   cols = ['0_0_0', '0_1_0']  
   blocks = ['0_0_0', '0_0_1']
   rcols = ['0_0', '0_1', '1_0', '1_1']  
   rblocks = ['0_0', '0_1', '1_1']
 
   rw = ['f', 'r']
   #draw figure
   start = 0.85
   stop = 0.15
   cm_subsection = np.linspace(start, stop, 5)
   colors = [cm.coolwarm(x) for x in cm_subsection]

   for psize in sizes:
       for op in rw:
           if op == 'f':
               data_sum = []
               pos = []
               cs = []
               ll = []
               for i, nset in enumerate(nsets):
                   set_pos = i+1
                   for j, wdef in enumerate(defs):
                       cpos = set_pos + (j+1)*0.2
                       cs.append(colors[j])
                       for per in data:
                           [rname, per_data] = per
                           now_set = psize + "_" + str(nset) + "_" + wdef + "_" + op
                           if now_set == rname:
                               data_sum.append(per_data)
                               pos.append(cpos)
                               if j%4 == 1:
                                   ll.append(nset)
                               else:
                                   ll.append("")
                   print (n, len(data_sum), psize)
                   bplot = plt.boxplot(data_sum, widths=0.2, positions=pos, notch='True',patch_artist=True, labels=ll)

                   for b in bplot:
                       for patch, color in zip(bplot['boxes'], cs):
                           patch.set_facecolor(color)

                   plt.ylabel("Aggregate Bandwidth, Unit: GB/s", fontsize=12)
                   plt.xlabel("Number of Datasets in a File", fontsize=12)
                   plt.rc('xtick', labelsize=11) 
                   plt.rc('ytick', labelsize=12) 
                   plt.legend([bplot["boxes"][0], bplot["boxes"][1], bplot["boxes"][2], bplot["boxes"][3], bplot["boxes"][4]], ['0_0_0', '1_0_0', '0_0_1', '1_0_1', '1_1_1'], loc='upper left')

                   Name = exp + '_' + "def"+ "_" + n + "_" + psize + "_" + op + ".pdf"
                   Name = os.path.join(exp, Name)
                   plt.savefig(Name)
                   plt.close()  

               data_sum = []
               pos = []
               cs = []
               ll = []
               for i, nset in enumerate(nsets):
                   set_pos = i+1
                   for j, col in enumerate(cols):
                       cpos = set_pos + (j+1)*0.2
                       cs.append(colors[j])
                       for per in data:
                           [rname, per_data] = per
                           now_set = psize + "_" + str(nset) + "_" + col + "_" + op
                           if now_set == rname:
                               data_sum.append(per_data)
                               pos.append(cpos)
                               if j%2 == 1:
                                   ll.append(nset)
                               else:
                                   ll.append("")
                   print (n, len(data_sum), psize)
                   bplot = plt.boxplot(data_sum, widths=0.2, positions=pos, notch='True',patch_artist=True, labels=ll)

                   for b in bplot:
                       for patch, color in zip(bplot['boxes'], cs):
                           patch.set_facecolor(color)

                   plt.ylabel("Aggregate Bandwidth, Unit:GB/s", fontsize=12)
                   plt.xlabel("Number of Datasets in a File", fontsize=12)
                   plt.rc('xtick', labelsize=11) 
                   plt.rc('ytick', labelsize=12) 
                   plt.legend([bplot["boxes"][0], bplot["boxes"][1]], ['independent', 'collective'], loc='upper left')

                   Name = exp + '_' + "col"+ "_" + n + "_" + psize + "_" + op + ".pdf"
                   Name = os.path.join(exp, Name)
                   plt.savefig(Name)
                   plt.close()  

               data_sum = []
               pos = []
               cs = []
               ll = []
               for i, nset in enumerate(nsets):
                   set_pos = i+1
                   for j, block in enumerate(blocks):
                       cpos = set_pos + (j+1)*0.2
                       cs.append(colors[j])
                       for per in data:
                           [rname, per_data] = per
                           now_set = psize + "_" + str(nset) + "_" + block + "_" + op
                           if now_set == rname:
                               data_sum.append(per_data)
                               pos.append(cpos)
                               if j%2 == 1:
                                   ll.append(nset)
                               else:
                                   ll.append("")
                   print (n, len(data_sum), psize)
                   bplot = plt.boxplot(data_sum, widths=0.2, positions=pos, notch='True',patch_artist=True, labels=ll)

                   for b in bplot:
                       for patch, color in zip(bplot['boxes'], cs):
                           patch.set_facecolor(color)

                   plt.ylabel("Aggregate Bandwidth, Unit:GB/s", fontsize=12)
                   plt.xlabel("Number of Datasets in a File", fontsize=12)
                   plt.rc('xtick', labelsize=11) 
                   plt.rc('ytick', labelsize=12) 
                   plt.legend([bplot["boxes"][0], bplot["boxes"][1]], ['interleaved', 'at file start'], loc='upper left')

                   Name = exp + '_' + "block"+ "_" + n + "_" + psize + "_" + op + ".pdf"
                   Name = os.path.join(exp, Name)
                   plt.savefig(Name)
                   plt.close()  

           if op == 'r':
               data_sum = []
               pos = []
               cs = []
               ll = []
               for i, nset in enumerate(nsets):
                   set_pos = i+1
                   for j, col in enumerate(rcols):
                       cpos = set_pos + (j+1)*0.2
                       cs.append(colors[j])
                       for per in data:
                           [rname, per_data] = per
                           now_set = psize + "_" + str(nset) + "_" + col + "_" + op
                           if now_set == rname:
                               data_sum.append(per_data)
                               pos.append(cpos)
                               if j%4 == 1:
                                   ll.append(nset)
                               else:
                                   ll.append("")
                   print (n, len(data_sum), psize)
                   bplot = plt.boxplot(data_sum, widths=0.2, positions=pos, notch='True',patch_artist=True, labels=ll)

                   for b in bplot:
                       for patch, color in zip(bplot['boxes'], cs):
                           patch.set_facecolor(color)

                   plt.ylabel("Aggregate Bandwidth, Unit:GB/s", fontsize=12)
                   plt.xlabel("Number of Datasets in a File", fontsize=12)
                   plt.rc('xtick', labelsize=11) 
                   plt.rc('ytick', labelsize=12) 
                   plt.legend([bplot["boxes"][0], bplot["boxes"][1], bplot["boxes"][2],bplot["boxes"][3] ], ['0_0', '0_1', '1_0', '1_1'], loc='upper left')

                   Name = exp + '_' + "col"+ "_" + n + "_" + psize + "_" + op + ".pdf"
                   Name = os.path.join(exp, Name)
                   plt.savefig(Name)
                   plt.close()  

               data_sum = []
               pos = []
               cs = []
               ll = []
               for i, nset in enumerate(nsets):
                   set_pos = i+1
                   for j, block in enumerate(rblocks):
                       cpos = set_pos + (j+1)*0.2
                       cs.append(colors[j])
                       for per in data:
                           [rname, per_data] = per
                           now_set = psize + "_" + str(nset) + "_" + block + "_" + op
                           if now_set == rname:
                               data_sum.append(per_data)
                               pos.append(cpos)
                               if j%2 == 1:
                                   ll.append(nset)
                               else:
                                   ll.append("")
                   print (n, len(data_sum), psize)
                   bplot = plt.boxplot(data_sum, widths=0.2, positions=pos, notch='True',patch_artist=True, labels=ll)

                   for b in bplot:
                       for patch, color in zip(bplot['boxes'], cs):
                           patch.set_facecolor(color)

                   plt.ylabel("Aggregate Bandwidth, Unit:GB/s", fontsize=12)
                   plt.xlabel("Number of Datasets in a File", fontsize=12)
                   plt.rc('xtick', labelsize=11) 
                   plt.rc('ytick', labelsize=12) 
                   plt.legend([bplot["boxes"][0], bplot["boxes"][1]], ['interleaved', 'at file start'], loc='upper left')

                   Name = exp + '_' + "block"+ "_" + n + "_" + psize + "_" + op + ".pdf"
                   Name = os.path.join(exp, Name)
                   plt.savefig(Name)
                   plt.close()  


def collect_data(mdir):

    exp = 'metadata' 
    if os.path.isdir(exp):
        shutil.rmtree(exp)
    os.mkdir(exp)

    edir = os.path.join(mdir, exp)
    for nexp in os.listdir(edir):
        data = []
        ndir = os.path.join(edir, nexp)
        for setting in os.listdir(ndir):
            sdir = os.path.join(ndir, setting)
            band_dir = os.path.join(sdir, "darshan/time")
            band_inform = read_file(band_dir)
            inform = setting.split("_")
            asize = float(inform[0].replace("m", ""))/1024
            nset = int(inform[1])
            node = int(nexp.replace("node", ""))
            for i, per in enumerate(band_inform):
                band_inform[i] = asize*nset*node/float(band_inform[i].split()[0])
            data.append([setting, band_inform])
        
        print_box(exp, nexp, data)
def main():
    for machine in machines:
        mdir = os.path.join(rdir, machine)
        collect_data(mdir) 

main()
