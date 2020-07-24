import os
import matplotlib as mpl
if os.environ.get('DISPLAY','') == '':
    mpl.use('Agg')
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import shutil
from scipy import stats

machines = ["summit"]
experiments = ["collective"]
data_dir = "/gpfs/alpine/stf008/scratch/bing/darshan/hdf5"
runs = ["summit_collective"]
rdir = "/ccs/home/bing/hdf5/data"
nodes = [2, 8, 32, 128]
insuf = "insufficient"
threshold = 0.2
interval = 0.95
cut = 30

def relative_error(confidence_interval, x):
    mean_value = np.mean(x)
    total = 0
    for per in x:
        total += np.power(per-mean_value, 2)

    var = total/len(x)
    z_alpha_2 = stats.t.ppf(1-(1-confidence_interval)/2, len(x)-1)
    std = np.power(var, 1.0/2)*z_alpha_2
    relative_value = std/mean_value

    return relative_value


def read_file(data_file):
    d_f = open(data_file, 'r')
    dfile = d_f.readlines()
    d_f.close()

    return dfile

def process_raw(datafile, n, io):
    #log data
    inform = read_file(datafile)
    #open time
    osum = []
    #end to end time
    asum = []
    # read/write time
    rwsum = []
    #close time
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
                if io == "r":
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
        atimes = []
        rwtimes = []
        ctimes = []
        for j in range(nmin):
            otime = o_stop[j] - o_start[j]
            #end to end times from file create to file close
            atime = c_stop[j] - o_start[j]
            rwtime = rw_stop[j] - rw_start[j]
            ctime = c_stop[j] - c_start[j]
            otimes.append(otime)
            atimes.append(atime)
            rwtimes.append(rwtime)
            ctimes.append(ctime)
             
        osum.append(otimes)
        asum.append(atimes)
        rwsum.append(rwtimes) 
        csum.append(ctimes)
   
    aopen = []
    agrw = []
    rw = []
    aclose = []
    ostraggler = []
    rwstraggler = []
    cstraggler = []
    for j in range(nmin):
        ao = []
        arw = []
        ab = []
        ac = [] 
        for i in range(n):
            ao.append(osum[i][j])
            arw.append(asum[i][j])
            ab.append(rwsum[i][j])
            ac.append(csum[i][j])
        aopen.append(np.max(ao))
        agrw.append(np.max(arw))
        rw.append(np.max(ab))
        aclose.append(np.max(ac))
      
        #straggler: the worst / median value
        ostraggler.append(np.max(ao)/np.median(ao))
        rwstraggler.append(np.max(ab)/np.median(ab))
        cstraggler.append(np.max(ac)/np.median(ac)) 

    return [aopen, aclose, agrw, rw, ostraggler, rwstraggler, cstraggler]

def get_bandwidth(agrw, rw, asize, n):
    #aggregate size, unit: GB
    if 'k' in asize:
        size=float(asize.replace('k', ''))/1024/1024
    elif 'm' in asize:
        size=float(asize.replace('m', ''))/1024
    elif 'g' in asize:
        size=float(asize.replace('g', ''))
    #aggregate bandwidth
    for i, per in enumerate(agrw):
        agrw[i] = n*size/per
        rw[i] = n*size/rw[i]
    return [agrw, rw] 

def plot_result(summary, n, op):
    #organize data
    basic_apis = ["POSIX", "MPIIO", "HDF5","HDF5C", "HDF51m", "HDF51mC", "HDF54m", "HDF54mC", "HDF516m", "HDF516mC", "HDF564m", "HDF564mC", "HDF5256m", "HDF5256mC"] 
    asize = ["1k", "16k", "256k", "1m", "16m", "256m", "1g"]
    modes = ["f", "w",  "r"]
    colors = ['blue', 'green', 'red']

    for size in asize:
        #generate figure per size
        fig, ax = plt.subplots()
        i = 1
        for api in basic_apis:
            pos = [i+0.2, i+0.4, i+0.6] 
            api_perf = []
            for mode in modes:
                mode_perf = []
                for per in summary:
                    [performance, setting] = per              
                    [papi, psize, pmode] = setting
                    if size == psize and api == papi and mode == pmode:
                        mode_perf.append(performance)   
                api_perf.append(mode_perf)
            aperf = ax.boxplot(api_perf, positions = pos, widths =0.2, patch_artist=True)
            for patch, color in zip(aperf['boxes'], colors):
                patch.set_facecolor(color)
            i += 1
        tname = op + " " + size
        ax.set_title(tname, fontsize=8)
        ax.legend([aperf["boxes"][0], aperf["boxes"][1], aperf["boxes"][2]],["write flush", "write",  "read"],
loc='upper right',  ncol=3)
        plt.setp(ax, xticks=[1.2, 2.2, 3.2, 4.2, 5.2, 6.2, 7.2, 8.2, 9.2, 10.2, 11.2, 12.2, 13.2, 14.2], xticklabels=basic_apis)
        plt.rc('xtick', labelsize=4)
        ax.set_xlim(1, 15)
        if op == 'bandwidth':
            ax.set_ylabel('Aggregate Bandwidth, unit:GB/s')
        else:
            ax.set_ylabel('Time, Unit:second')
        name = op + "_" + size + "_node" + str(n) + ".pdf"
        ndir = os.path.join(rdir, name)
        plt.savefig(ndir)

def build_insufficient(per, iff, exp):
    [api, asize, ncores, nblocks] = per
    if 'k' in asize:
        wsize = asize.replace("k", "")
        unit = 'k'
    if 'm' in asize:
        wsize = asize.replace("m", "")
        unit = 'm'
    if 'g' in asize:
        wsize = asize.replace("g", "")
        unit = 'g'

    doneline = "done" + '\n'

    apiline = "for api in '" + api + "'; do" + '\n'
    iff.write(apiline)
    if exp == "baseline":
        sizeline = "for size in '" + wsize + "'; do" + '\n'
        iff.write(sizeline)
    elif exp == "blocks":
        sizeline = "for aggr in '" + wsize + "'; do" + '\n'
        iff.write(sizeline)
    elif exp == "collective":
        sizeline = "for aggr in '" + wsize + "'; do" + '\n'
        iff.write(sizeline)
   
    unitline = "for unit in '" + unit + "'; do" + '\n'
    iff.write(unitline)
    if exp == "blocks":
        blockline = "for nblock in '" + nblocks + "'; do" + '\n'
        iff.write(blockline)
        iorline = "ior $i $api $aggr $unit $nblock" + '\n'
        iff.write(iorline)
        iff.write(doneline)
        
    elif exp == "collective":
        collectiveline = "for proc in '" + ncores + "'; do" + '\n'
        iff.write(collectiveline)
        iorline = "ior $i $api $aggr $unit $proc" + '\n'
        iff.write(iorline)
        iff.write(doneline)
    if exp == "baseline":
        iorline = "ior $i $api $size $unit" + '\n'
        iff.write(iorline)

    iff.write(doneline)
    iff.write(doneline)
    iff.write(doneline)
 




#we summarize IO R  results here
def per_results(run_dir, result_dir, exp, imdir):

    for d in os.listdir(run_dir):
        for n in nodes:
            name="node"+str(n)
            ndir = os.path.join(result_dir, name)
            #plot per node setting
            opensum = []
            bandsum = []
            rwsum = []
            closesum = []
            insufficient = []

            if name == d:
                ddir = os.path.join(run_dir, d)
                for f in os.listdir(ddir):
                    if '.' not in f:
                        #api hdf5setting size r/w  in filename
                        inform = f.split("_")
                        print (inform)
                        if exp == "baseline":
                            api = inform[0]
                            asize = inform[1]
                            io = inform[2]
                            nblocks = "1"
                            ncores = "1"
                        elif exp == "blocks":
                            api = inform[0]
                            asize = inform[1]
                            nblocks = inform[2]
                            io = inform[3]
                            ncores = "1"
                        elif exp == "collective":
                            api = inform[0]
                            asize = inform[1]
                            ncores = inform[2]
                            io = inform[3]
                            nblocks = "1"
 
                        setting = [api, asize, io]
                        #process data
                        datafile = os.path.join(ddir, f)
                        [aopen, aclose, agrw, rw, ostraggler, rwstraggler, cstraggler] = process_raw(datafile, n, io)
                        [aband, band] = get_bandwidth(agrw, rw, asize, n)
                        rname = api + "_" + asize + "_" + ncores + "_" + nblocks + "_" + io
                        rd_dir = os.path.join(ndir, rname)
                        if not os.path.exists(rd_dir):
                            os.makedirs(rd_dir)
                        #write aggregate bandwidth result
                        rfile = os.path.join(rd_dir, "aggregate-bandwidth")
                        rf = open(rfile, 'a')
                        for per in aband:
                            line_string = str(per) + '\n' 
                            rf.write(line_string)
                        rf.truncate()
                        rf.close()
 
                        #check data stability
                        if io == 'r' or io == 'f':
                            if len(agrw) < cut or relative_error(interval, agrw) > threshold:
                                
                                api = api.replace("C", "")
                                if [api, asize, ncores, nblocks] not in insufficient:
                                    insufficient.append([api, asize, ncores, nblocks])
 
                        #write bandwidth result
                        rfile = os.path.join(rd_dir, "rw-bandwidth")
                        rf = open(rfile, 'a')
                        for per in band:
                            line_string = str(per) + '\n' 
                            rf.write(line_string)
                        rf.truncate()
                        rf.close()

                        #open result
                        rfile = os.path.join(rd_dir, "open")
                        rf = open(rfile, 'a')
                        for per in aopen:
                            line_string = str(per) + '\n' 
                            rf.write(line_string)
                        rf.truncate()
                        rf.close()

                        #close result
                        rfile = os.path.join(rd_dir, "close")
                        rf = open(rfile, 'a')
                        for per in aclose:
                            line_string = str(per) + '\n' 
                            rf.write(line_string)
                        rf.truncate()
                        rf.close()

                        #open straggler result
                        rfile = os.path.join(rd_dir, "open-straggler")
                        rf = open(rfile, 'a')
                        for per in ostraggler:
                            line_string = str(per) + '\n' 
                            rf.write(line_string)
                        rf.truncate()
                        rf.close()

                        #close straggler result
                        rfile = os.path.join(rd_dir, "close-straggler")
                        rf = open(rfile, 'a')
                        for per in cstraggler:
                            line_string = str(per) + '\n' 
                            rf.write(line_string)
                        rf.truncate()
                        rf.close()

                        #read write straggler result
                        rfile = os.path.join(rd_dir, "rw-straggler")
                        rf = open(rfile, 'a')
                        for per in cstraggler:
                            line_string = str(per) + '\n' 
                            rf.write(line_string)
                        rf.truncate()
                        rf.close()
            
            ifile = os.path.join(imdir, name)
            iff = open(ifile, 'a')
            for per in insufficient:
                build_insufficient(per, iff, exp)

            iff.truncate()
            iff.close()                


def main():
    for machine in machines:
        for exp in experiments:
            result_dir = os.path.join(rdir, machine + "/" + exp)
            if  os.path.exists(result_dir):
                shutil.rmtree(result_dir)

            imdir = os.path.join(insuf, machine + "/" + exp)
            if os.path.isdir(imdir):
                shutil.rmtree(imdir)
            os.makedirs(imdir)

            for run in runs:
                run_dir = os.path.join(data_dir, run)
                run_dir = os.path.join(run_dir, machine + "_"+exp)
                per_results(run_dir, result_dir, exp, imdir)                                

main()                                   
