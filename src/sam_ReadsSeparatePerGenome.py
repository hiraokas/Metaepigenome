#!/usr/bin/env python
#coding: UTF-8

import sys 
import re
import os
import subprocess
import unittest
import time 
import pandas
from Bio import SeqIO
from Bio.Seq import Seq
from Bio.SeqRecord import SeqRecord

def _help():
    print("""
===================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20250111
    History: 20251225
    - This is a script for sepalating BAM file per genomes mapped on. 
    - genomeID is automatically retrieved. When the seqID of the mapped reference sequence is P-SAGv0.4_xxx_NSOL_001_2, the genomeID is P-SAGv0.4_xxx_NSOL_001  
    - input: m64088_211023_100220/179044496/ccs/fwd  2064    P-SAGv0.4_xxx_NSOL_001_2        105     0....
Usage:
    This.py map.SAM
Output:
    MapSep-XXX.sam
===================================================================================================================================
    """)

#-------------------------------------------
def _int_dict():
    return collections.defaultdict(int)
def _float_dict():
    return collections.defaultdict(float)
def _list_dict():
    return collections.defaultdict(list)

#-------------------------------------------
if __name__=='__main__':
    #option
    argvs = sys.argv
    argc  = len(argvs)
    if argc==1 or argvs[1]=="-h":
        print("[ERROR] no inpu file name.")
        _help()
        exit()

    input_SAM    = argvs[1]  
    basename_SAM = os.path.splitext(os.path.basename(input_SAM))[0]  # pbmm2HiFi_P-SAGv0.4_fixmask_NSOL.hifi_kinetics_sorted
    output_path  = "../ReadSeparation/MapSep-{}".format(basename_SAM)
    os.makedirs(output_path, exist_ok=True)

    # Time log
    start_time = time.time()

    print("Run sam_ReadsSeparatePerGenome.py")
    # read BAM by chunk
    chunk_size = 10
    col_name   = range(1,24,1)
    chunks     = pandas.read_table(input_SAM, chunksize = chunk_size, header = None, names = col_name)  #, usecols=[0, 1, 2]
    #     #m64088_211023_100220/179044496/ccs/fwd  2064    P-SAGv0.4_xxx_NSOL_001_2        105     0   ...
    #     #m64088_211023_100220/100338195/ccs/fwd  0       P-SAGv0.4_xxx_NSOL_001_2        3799    29  ...
    #     #m64088_211023_100220/100338195/ccs/rev  16      P-SAGv0.4_xxx_NSOL_001_2        3799    29  ...
    #     #m64088_211023_100220/69533915/ccs/rev   0       P-SAGv0.4_xxx_NSOL_001_2        11314   60  ...
    #     #m64088_211023_100220/69533915/ccs/fwd   16      P-SAGv0.4_xxx_NSOL_001_2        11314   60  ...

    current_genomeID = ""
    header_lines_HD  = []
    header_lines_SQ  = []
    header_lines_RG  = []
    header_lines_PG  = []
    for chunk in chunks:
        #print(chunk)
        for index, line in chunk.iterrows():
            #print(line)
            
            #header information----------------
            if line[1][0] == "@":
                #print(line)

                #store header information
                if   line[1] == "@HD":
                    header_lines_HD.append("\t".join([x for x in [str(i) for i in (line.to_list())] if x != "nan"]))
                    continue
                elif line[1] == "@SQ":
                    header_lines_SQ.append("\t".join([x for x in [str(i) for i in (line.to_list())] if x != "nan"]))
                    continue
                elif line[1] == "@RG":
                    header_lines_RG.append("\t".join([x for x in [str(i) for i in (line.to_list())] if x != "nan"]))
                    continue
                elif line[1] == "@PG":
                    header_lines_PG.append("\t".join([x for x in [str(i) for i in (line.to_list())] if x != "nan"]))
                    continue
                else:
                    print(line)
                    print("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@")

            #open new file if move to next genome
            genomeID = line[3].rsplit("_",1)[0]  # P-SAGv0.4_xxx_NSOL_001_2 -> P-SAGv0.4_xxx_NSOL_001
            #print(genomeID)

            if current_genomeID != genomeID:
                # first iteration
                if current_genomeID != "": 
                    f.close()

                # Open output sam file
                current_genomeID = genomeID
                f = open("{}/MapSep-{}_{}.sam".format(output_path, basename_SAM, genomeID), mode = 'w', buffering = 2**14)  #16384 = 16KB
                print("Move to next genomeID: {}".format(genomeID))

                # write header: @HD : copy
                for headerline in header_lines_HD:
                    f.write(headerline+"\n")

                # write header: @SQ : select by reference sequence ID
                for headerline in header_lines_SQ:
                    if "SN:{}_".format(current_genomeID) in headerline.split()[1]:   #SN:P-SAGv0.4_xxx_NSOL_001_22
                        f.write(headerline+"\n")

                # write header: @RG : copy
                for headerline in header_lines_RG:
                    f.write(headerline+"\n")

                # write header: @PG : copy
                for headerline in header_lines_PG:
                    f.write(headerline+"\n")

                # add PG line in the end of header section
                headerline = "\t".join(["@PG",
                                 "ID:sam_ReadsSeparatePerGenome.py",
                                 "PN:sam_ReadsSeparatePerGenome.py",
                                 "VN:1.0",
                                 "CL:{}".format(" ".join(argvs)) ])
                f.write(headerline+"\n")

            #body ------------------
            body_line = "\t".join([x for x in [str(i) for i in (line.to_list())] if x != "nan"])
            #print(body_line)
            f.write(body_line+"\n")

    f.close()

    # Time log
    end_time = time.time()
    print("Running time: {}".format(end_time - start_time))

    print("Output: {}".format(output_path))
    print("all done.")
    exit()


