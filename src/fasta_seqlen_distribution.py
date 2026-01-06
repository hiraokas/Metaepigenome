#!/usr/bin/env python3

import os
import sys
import re
import collections
import glob
import numpy
from collections import defaultdict
from Bio import SeqIO
from tqdm import tqdm

def _help():
    print("""
==================================================================================================================================================================================
Description: 
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    created: 20170724
    History: 20200128
    History: 20251225
    - Sequence length list
    - Calculate average length with sd
    - Caluclate total bases and count up total sequence number
USAGE:
    conda activate py39
    python3 fasta_seqlen_distribution.py input.fasta/q [window_size=100; int]
==================================================================================================================================================================================
    """)

def _int_dict():
    return collections.defaultdict(int)

if __name__=='__main__':
    output_filepath     = "../SummaryInformation/"
    os.mkdir(output_filepath) if not os.path.exists(output_filepath) else print("Output dir already exist: {}".format(output_filepath))

    list_length    = []
    dict_genecount = defaultdict(int)  #readid:genecount

    param = sys.argv
    if len(param)<2:
        _help()
        exit()

    fasta_file          = param[1]
    BaseRankNum         = 100
    if len(param)>=3: 
        BaseRankNum     = int(param[2])
    Basename_output     = fasta_file.rsplit("/",1)[1].rsplit(".",1)[0]  
    outputfilename_rank ="{}/rank_{}_{}.tsv".format(output_filepath, Basename_output, BaseRankNum)

    print("""
==================================================================
fasta_file:      {}
Rank:            {}
output_filename: {}
==================================================================
    """.format(fasta_file, BaseRankNum, Basename_output))

    if os.path.isfile(outputfilename_rank):
        print("Output file already exist: {}".format(outputfilename_rank))
        exit()

    #filetype
    root, ext = os.path.splitext(fasta_file)
    if   ext in [".fastq", ".fq"]:
        file_type = "fastq"
    elif ext in [".fasta", ".fa", ".faa", ".fna"]:
        file_type = "fasta"
    else:
        print("undefined file type: {}".format(fasta_file))
        _help()
        exit()

    print("{} mode...".format(file_type))

    seq_len_dict    = {}  #{seq_ID: length}

    total_line = sum(1 for line in open(fasta_file))
    pbar       = tqdm(total = total_line)

    print("File reading...: {}".format(fasta_file))
    FastaFile   = open(fasta_file, 'r')
    for rec in SeqIO.parse(FastaFile, file_type):
            name   = rec.id
            seq    = rec.seq
            seqLen = len(rec)
            if name in seq_len_dict.keys():
                name = name + "_2"

            seq_len_dict[name] = seqLen

            pbar.update(4)
    FastaFile.close()

    #sequence length
    average = numpy.average( numpy.array( list( seq_len_dict.values())))
    sd      = numpy.std(     numpy.array( list( seq_len_dict.values())))
    print("length: {:.0f} ± {:.0f}".format(average, sd))

    #total
    total_base = sum(seq_len_dict.values())
    print("total base: {}".format(total_base))

    seq_num = len(seq_len_dict.keys())
    print("sequence number: {}".format(seq_num))

    #rank distribution
    dict_genecount = _int_dict()  #{window:count}
    for seq_id, seq_len in seq_len_dict.items():
        dict_genecount[str(seq_len//BaseRankNum)] += 1

    #print(count_dict)  
    with open(outputfilename_rank, 'w') as f:
        for window, count in sorted(dict_genecount.items(), key = lambda x: int(x[0])):
            line = "{}\t{}\n".format( int(window) * BaseRankNum, count)
            f.write(line)
            #print(line.strip())

    print("Output: " + outputfilename_rank)
    
