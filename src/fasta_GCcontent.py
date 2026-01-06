#!/usr/bin/env python
#coding: UTF-8

import sys 
import re
import os
import glob
import copy
from bisect import bisect
import collections

def _help():
    print("""
==================================================================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20200502
    History: 20250813 (accept multiple files and wilecard)
    History: 20251225
    - Calculate GC content of each given multi-fasta file
    - std output
Usage:
    this.py genome.FASTA
    this.py genome1.FASTA genome2.FASTA genome3.FASTA ...
    this.py genome*.FASTA
Output format:
    filename GCcontent(0-100%)
==================================================================================================================================================================================
""")

def _int_dict():    return collections.defaultdict(int)

def _count_GC(seq):
    return seq.count('G') + seq.count('C')

def _comp_GCcontent(seq):
    total_ATCG_count = len(seq) - seq.count('N')
    total_GC_count   = _count_GC(seq)

    avGC = total_GC_count*100/float(total_ATCG_count) if total_ATCG_count != 0 else 0
    #print ("GC content:   "+str(avGC))
    return avGC

def _comp_GCskew(seq): 
    total_ATCG_count  = len(seq)-seq.count('N')
    total_GC_count    = _comp_GCcontent(seq)
    total_GC_distance = seq.count('G') - seq.count('C')

    avGC_skew = float(total_GC_distance)/float(total_GC_count) if total_GC_count != 0 else 0
    #print ("GC skew  :   "+str(avGC_skew))     
    return avGC_skew

#============================================================================
#main
#============================================================================
if __name__=='__main__':

    argvs  = sys.argv 
    if len(argvs)<2:
        print("[ERROR] no inpu file name.")
        _help()
        exit()

    fasta_file_list = argvs[1:]
    
    for fasta_file in fasta_file_list:
        #============================================================================
        #open fasta file and calculate statistics
        #============================================================================
        Total_GC     = 0
        Total_length = 0
        fastafile  = open("%(fasta_file)s" % locals())
        for line in fastafile:
            if line.find(">") != -1:#ID lines
                continue
            else:#nucle lines
                line    = line.rstrip().upper()
                Total_GC     += _count_GC(line)
                Total_length += len(line)

        fastafile.close()

        gc_content = Total_GC / Total_length * 100
        print("{}\t{}".format(fasta_file, gc_content), flush=True)
