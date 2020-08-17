import os
import matplotlib as mpl
if os.environ.get('DISPLAY','') == '':
    mpl.use('Agg')
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import shutil
from scipy import stats
import subprocess as sp

machines = ["cori"]
experiments = ["baseline"]
data_dir = "/gpfs/alpine/csc300/world-shared"
rdir = "/ccs/home/bing/hdf5/data"
insuf = "insufficient"
nodes = [2, 8, 32, 128]
complete = "complete"
threshold = 0.2
interval = 0.8
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

def record_complete(complete_file, datesum):
    cfile = open(complete_file, 'a')
    for datetime in datesum:
        line = datetime + '\n'
        cfile.write(line)
    cfile.truncate()
    cfile.close()

def complete_check(complete_file, datesum):

    check = "n"
    recorded = read_file(complete_file)
    for i, per in enumerate(recorded):
        recorded[i] = recorded[i].split()[0]
    
    for time in datesum:
        if time not in recorded:
            check = "n"
            break
        check = "y"   
 
    return check 

def time_check(dinform):

    datesum = []
    for line in dinform:
        if "Finished" in line:
            tinform = line.split()
            date = ' '.join(str(f) for f in tinform[2:])
            cmd = 'date --date="' + date + '" +%s'
            datetime = sp.getoutput(cmd)
            datesum.append(datetime)

    return datesum


def read_file(data_file):
    d_f = open(data_file, 'r')
    dfile = d_f.readlines()
    d_f.close()

    return dfile

def process_raw(dinform, n, io):

    #open time
    osum = []
    #end to end time
    asum = []
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

        for line in dinform:
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
 


        if len(c_stop) < nmin:
            nmin = len(c_stop) 
        otimes = []
        atimes = []
        ctimes = []
        for j in range(nmin):
            otime = o_stop[j] - o_start[j]
            #end to end times from file create to file close
            atime = c_stop[j] - o_start[j]
            ctime = c_stop[j] - c_start[j]
            otimes.append(otime)
            atimes.append(atime)
            ctimes.append(ctime)
             
        osum.append(otimes)
        asum.append(atimes)
        csum.append(ctimes)
   
    aopen = []
    agrw = []
    aclose = []
    ostraggler = []
    cstraggler = []
    for j in range(nmin):
        ao = []
        arw = []
        ac = [] 
        for i in range(n):
            ao.append(osum[i][j])
            arw.append(asum[i][j])
            ac.append(csum[i][j])
        aopen.append(np.max(ao))
        agrw.append(np.max(arw))
        aclose.append(np.max(ac))
      
        #straggler: the worst / median value
        ostraggler.append(np.max(ao)/np.median(ao))
        cstraggler.append(np.max(ac)/np.median(ac)) 

    return [aopen, aclose, agrw, ostraggler, cstraggler]

def get_bandwidth(agrw, asize, n):

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

    return agrw 

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
        iorline = "ior $i $api $aggr $unit" + '\n'
        iff.write(iorline)

    iff.write(doneline)
    iff.write(doneline)
    iff.write(doneline)


def insufficient_check(imdir, result_dir, n, exp):

   
    name = "node" + str(n)
    rdir = os.path.join(result_dir, name)
    idir = os.path.join(imdir, rdir)
    insufficient = []
 
    for rname in os.listdir(rdir):
        [api, asize, ncores, nblocks, io] = rname.split("_")
        #check data stability
        rnamefile = os.path.join(rdir, rname + "/time-total")
        agrw = []
        rinform = read_file(rnamefile)
        for line in rinform:
            bandwidth = float(line.split()[0])
            agrw.append(bandwidth)
        agrw = list(set(agrw))
        if len(agrw) < cut and relative_error(interval, agrw) > threshold:
            print (rname,  relative_error(interval, agrw), len(agrw))
            if [api, asize, ncores, nblocks] not in insufficient:
                insufficient.append([api, asize, ncores, nblocks])

    ifile = os.path.join(imdir, name)
    iff = open(ifile, 'a')
    for per in insufficient:
        build_insufficient(per, iff, exp)

    iff.truncate()
    iff.close()                

def process_one(inform, name, rname, rdir, exp, dinform, datesum, n, asize, io, run):

#process data
    print (inform, name, exp)
    [aopen, aclose, agrw, ostraggler, cstraggler] = process_raw(dinform, n, io)
    aband = get_bandwidth(agrw, asize, n)
    nd_dir = os.path.join(rdir, name)
    rd_dir = os.path.join(nd_dir, rname)
    if not os.path.exists(rd_dir):
        os.makedirs(rd_dir)
    #write aggregate bandwidth result
    rfile = os.path.join(rd_dir, "aggregate-bandwidth")
    rf = open(rfile, 'a')
    print (len(aband), len(datesum))
    aband_len = len(aband)
    date_len = len(datesum)
    record_len = min(aband_len, date_len)
    for i in range(record_len):
        line_string = str(aband[i]) + ' ' + datesum[i] + '\n' 
        rf.write(line_string)
    rf.truncate()
    rf.close()
 
    #write aggregate bandwidth result
    rfile = os.path.join(rd_dir, "time-total")
    rf = open(rfile, 'a')
    for i in range(record_len):
        line_string = str(agrw[i]) + ' ' + datesum[i] + '\n' 
        rf.write(line_string)
    rf.truncate()
    rf.close()
 
    #open result
    rfile = os.path.join(rd_dir, "open")
    rf = open(rfile, 'a')
    for i in range(record_len):
        line_string = str(aopen[i]) + ' ' + datesum[i] + '\n' 
        rf.write(line_string)
    rf.truncate()
    rf.close()

    #close result
    rfile = os.path.join(rd_dir, "close")
    rf = open(rfile, 'a')
    for i in range(record_len):
        line_string = str(aclose[i]) + ' ' + datesum[i] + '\n' 
        rf.write(line_string)
    rf.truncate()
    rf.close()

    #open straggler result
    rfile = os.path.join(rd_dir, "open-straggler")
    rf = open(rfile, 'a')
    for i in range(record_len):
        line_string = str(ostraggler[i]) + ' ' + datesum[i] + '\n' 
        rf.write(line_string)
    rf.truncate()
    rf.close()

    #close straggler result
    rfile = os.path.join(rd_dir, "close-straggler")
    rf = open(rfile, 'a')
    for i in range(record_len):
        line_string = str(cstraggler[i]) + ' ' + datesum[i] + '\n' 
        rf.write(line_string)
    rf.truncate()
    rf.close()


def per_results(ddir, rdir, machine, exp, n, run): 

    name="node"+str(n)
    #plot per node setting
    opensum = []
    bandsum = []
    closesum = []
   
    for f in os.listdir(ddir):
        if '.' not in f and f != "ior_data":
            #api hdf5setting size r/w  in filename
            inform = f.split("_")
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

            if io == 'r' or io == 'f':
              if "CC" not in api:
                rname = api + "_" + asize + "_" + ncores + "_" + nblocks + "_" + io
                datafile = os.path.join(ddir, f)
                dinform = read_file(datafile)
                datesum = time_check(dinform)

                #check completeness
                complete_dir = os.path.join(complete, machine + "/" + exp + "/" + name)
                complete_file = os.path.join(complete_dir, rname)
                if os.path.isfile(complete_file):
                    complete_inform = read_file(complete_file)
                    check = complete_check(complete_file, datesum)
                    if check == "n":
                        process_one(inform, name, rname, rdir, exp, dinform, datesum, n, asize, io, run) 
                        record_complete(complete_file, datesum) 
                    print (check, run)
                else:
                    if not os.path.isdir(complete_dir):
                        os.makedirs(complete_dir)
                    process_one(inform, name, rname, rdir, exp, dinform, datesum, n, asize, io, run) 
                    record_complete(complete_file, datesum) 



def main():
    for machine in machines:
        for exp in experiments:
            result_dir = os.path.join(rdir, machine + "/" + exp)
            imdir = os.path.join(insuf, machine + "/" + exp)
            #every time rebuild the insufficient record from scratch 
            if  os.path.isdir(imdir):
                shutil.rmtree(imdir)
            os.makedirs(imdir)

            edir = os.path.join(data_dir, machine + "_"+exp)
            for n in nodes:
                for run in os.listdir(edir):
                    run_dir = os.path.join(edir, run)
                    nname = "node" + str(n)
                    ndir = os.path.join(run_dir, nname)
                    if os.path.isdir(ndir):
                        per_results(ndir, result_dir, machine, exp, n, run)

                insufficient_check(imdir, result_dir, n, exp)          

main()                                   
