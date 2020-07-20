import os
import matplotlib as mpl
if os.environ.get('DISPLAY','') == '':
    mpl.use('Agg')
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np

nodes = [2, 8, 32, 128]
data_dir = "/home/fix/work/hdf5/paper/result/summit_blocks/summit_blocks"
rdir = "bandwidth_result"

def read_file(data_file):
    d_f = open(data_file, 'r')
    dfile = d_f.readlines()
    d_f.close()

    return dfile

def process_raw(datafile, n, mode):
    inform = read_file(datafile)
    osum = []
    rwsum = []
    irwsum = []
    csum = []
    nmin = 1000000000
    for i in range(0, n):
        taski= "Task="+str(i)
        #open start end
        o_start = []
        o_stop = []
        #read/write start end
        rw_start = []
        rw_stop = []
        #close start end
        c_start = []
        c_stop = []
        for line in inform:
            if taski in line:
                if mode == "r":
                    if "read open start" in line:
                        po_start=float(line.split()[4].replace("Time=","").replace(",", ""))
                        o_start.append(po_start)
                    if "read open stop" in line:
                        po_stop=float(line.split()[4].replace("Time=","").replace(",", ""))
                        o_stop.append(po_stop)
                    if "read start" in line:
                        prw_start=float(line.split()[4].replace("Time=","").replace(",", ""))
                        rw_start.append(prw_start)
                    if "read stop" in line:
                        prw_stop=float(line.split()[4].replace("Time=","").replace(",", ""))
                        rw_stop.append(prw_stop)
                    if "read close start" in line:
                        pc_start=float(line.split()[4].replace("Time=","").replace(",", ""))
                        c_start.append(pc_start)
                    if "read close stop" in line:
                        pc_stop=float(line.split()[4].replace("Time=","").replace(",", ""))
                        c_stop.append(pc_stop)
 
                else:
                    if "write open start" in line:
                        po_start=float(line.split()[4].replace("Time=","").replace(",", ""))
                        o_start.append(po_start)
                    if "write open stop" in line:
                        po_stop=float(line.split()[4].replace("Time=","").replace(",", ""))
                        o_stop.append(po_stop)
                    if "write start" in line:
                        prw_start=float(line.split()[4].replace("Time=","").replace(",", ""))
                        rw_start.append(prw_start)
                    if "write stop" in line:
                        prw_stop=float(line.split()[4].replace("Time=","").replace(",", ""))
                        rw_stop.append(prw_stop)
                    if "write close start" in line:
                        pc_start=float(line.split()[4].replace("Time=","").replace(",", ""))
                        c_start.append(pc_start)
                    if "write close stop" in line:
                        pc_stop=float(line.split()[4].replace("Time=","").replace(",", ""))
                        c_stop.append(pc_stop)
 


        o_start.sort()
        o_stop.sort()
        rw_start.sort()
        rw_stop.sort()
        c_start.sort()
        c_stop.sort()

        if len(c_stop) < nmin:
            nmin = len(c_stop) 
        otimes = []
        rwtimes = []
        irwtimes = []
        ctimes = []
        # use c_stop as measures
        for i, per in enumerate(c_stop):
            otime = o_stop[i] - o_start[i]
            #end to end times from file create to file close
            rwtime = c_stop[i] - o_start[i]
            ctime = c_stop[i] - c_start[i]
            irwtime = rw_stop[i] - rw_start[i]
            otimes.append(otime)
            rwtimes.append(rwtime)
            ctimes.append(ctime)
            irwtimes.append(irwtime) 
        osum.append(otimes)
        rwsum.append(rwtimes) 
        csum.append(ctimes)
        irwsum.append(irwtimes)

    aggopen = []
    aggrw = []
    aggclose = []
    aggirw = []
    for i in range(nmin):
        ao = []
        arw = []
        airw = []
        ac = [] 
        for j in range(n):
            ao.append(osum[j][i])
            arw.append(rwsum[j][i])
            airw.append(irwsum[j][i])
            ac.append(csum[j][i])
        aggopen.append(np.max(ao))
        aggrw.append(np.max(arw))
        aggirw.append(np.max(airw))
        aggclose.append(np.max(ac))
     
    return [aggopen, aggrw, aggclose, aggirw]

def sum_bandwidth(rwsum, irwsum, asize, n):
    #aggregate size, unit: GB
    if 'k' in asize:
        size=float(asize.replace('k', ''))/1024/1024
    elif 'm' in asize:
        size=float(asize.replace('m', ''))/1024
    elif 'g' in asize:
        size=float(asize.replace('g', ''))
    #aggregate bandwidth
    for i, per in enumerate(rwsum):
        rwsum[i] = n*size/per
        irwsum[i] = n*size/irwsum[i]
    return [rwsum, irwsum]


def plot_result(summary, n, op):
    #organize data
    basic_apis = ["POSIX", "MPIIO", "HDF5","HDF5C", "HDF51m", "HDF51mC", "HDF54m", "HDF54mC", "HDF516m", "HDF516mC", "HDF564m", "HDF564mC", "HDF5256m", "HDF5256mC"] 
    asize = ["16k", "256k", "16m", "256m", "1024m"]
    blocks = ["4", "8", "16"]
    modes = ["f", "w",  "r"]
    colors = ['blue', 'green', 'red']

    for size in asize:
        #generate figure per size
        fig, ax = plt.subplots(3)
        plt.subplots_adjust(hspace = .2)
        
        for i, mode in enumerate(modes):
            z = 1
            for api in basic_apis:
                pos = [z+0.2, z+0.4, z+0.6] 
                api_perf = []
                for block in blocks:
                    block_perf = []
                    for per in summary:
                        [performance, setting] = per              
                        [papi, psize, pblock, pmode] = setting
                        if size == psize and api == papi and block == pblock and mode == pmode:
                            block_perf.append(performance)   
                    api_perf.append(block_perf)

                aperf = ax[i].boxplot(api_perf, positions = pos, widths =0.2, patch_artist=True)
                for patch, color in zip(aperf['boxes'], colors):
                    patch.set_facecolor(color)
                z += 1
            tname = op + " " + mode + " " + size 
            ax[i].set_title(tname, fontsize=8)
#            ax[i].legend([aperf["boxes"][0], aperf["boxes"][1], aperf["boxes"][2]],blocks, loc='upper right',  ncol=3)
            plt.setp(ax[i], xticks=[1.2, 2.2, 3.2, 4.2, 5.2, 6.2, 7.2, 8.2, 9.2, 10.2, 11.2, 12.2, 13.2, 14.2], xticklabels=basic_apis)
            plt.rc('xtick', labelsize=4)
            ax[i].set_xlim(1, 15)
            if 'bandwidth' in op:
                ax[1].set_ylabel('Aggregate Bandwidth, unit:GB/s')
            else:
                ax[1].set_ylabel('Time, Unit:second')
    
        name = op + "_" + size + "_node" + str(n) + ".pdf"
        ndir = os.path.join(rdir, name)
        plt.savefig(ndir)

def main():
    if not os.path.exists(rdir):
        os.makedirs(rdir)
 
    for n in nodes:
        name="node"+str(n)
        #plot per node setting
        opensum = []
        abandsum = []
        apbandsum = []
        closesum = []
        for d in os.listdir(data_dir):
            if name == d:
                ddir = os.path.join(data_dir, d)
                for f in os.listdir(ddir):
                    if '.' not in f:
                        #api hdf5setting size r/w  in filename
                        inform = f.split("_")
                        api = inform[0]
                        asize = inform[1]
                        nblocks = inform[2]
                        mode = inform[3]
                        setting = [api, asize, nblocks, mode]
                        #process data
                        datafile = os.path.join(ddir, f)
                        [osum, rwsum, csum, irwsum] = process_raw(datafile, n, mode)
                        [bandsum, pbandsum] = sum_bandwidth(rwsum, irwsum, asize, n) 
                        opensum.append([osum, setting])
                        abandsum.append([bandsum, setting])
                        apbandsum.append([pbandsum, setting])
                        closesum.append([csum, setting])
        plot_result(opensum, n, 'open')
        plot_result(abandsum, n, 'aggrbandwidth')
        plot_result(apbandsum, n, 'bandwidth')
        plot_result(closesum, n, 'close')



main()                                   
