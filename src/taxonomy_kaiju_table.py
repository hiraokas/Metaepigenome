#!/usr/bin/env python
#coding: UTF-8

import os
import sys
import re
import collections
import taxonomy_table

def _help():
    print("""
=========================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    created: 20160308
    History: 20200417
    History: 20211228
    History: 20221012
    History: 20240402 (output each threshold={0.00||given})
    - Script for making table that 
        -conbined all sample data
        -count data by sample in each taxonomic clades (i.g. genus, family, order, class, phylam, domain)
Input:
    thresholf(float)
    dir_pass(contain Kraken_output.out files)
    Dirs with "_" in top of the name (i.e., "_XXX") will be ignored.
Output:
    many tables ("kaiju_XXX")
Usage:
    python3 taxonomy_kaiju_table.py taxonomy_dir [threshold=0.01]
Tips:
    python3  taxonomy_kaiju_table.py  ../taxonomy       0.01
    python3  taxonomy_kaiju_table.py  ../taxonomy/GORG  0.01
=========================================================================================================
   """)


Output_dir="../taxonomy"

if __name__=='__main__':

    argvs = sys.argv
    argc  = len(argvs)

    if argc<2 or argvs[1]=="-h":
        _help()
        exit()

    dir_pass=argvs[1]

    if argc<3:
        Other_threshold = 0.01
    elif argc>=3 and str.isdigit(argvs[2].replace(".","",1)):
        Other_threshold = float(argvs[2])
    else:
        print("Illigal number: {}".format(argvs[2]))
        exit()


    if not os.path.exists(dir_pass):
        print("The path not exist!")
        exit()

    dir_pass      = dir_pass.rstrip('/')
    dir_name      = dir_pass.rsplit("/",1)[1]
    Output_prefix = "{}/kaiju_{}_".format(Output_dir,dir_name)

    print("Roading taxonomy tables...")
    A=[]   
    for f in os.listdir(dir_pass):
        if not os.path.isdir(dir_pass+"/"+f): continue
        if f[0]=="_": continue  #_XXX wil be passed
        #print(f)
        A.append("{}/{}/{}_kairep.summary".format(argvs[1], f, f))  #../taxonomy/M0000N000ENE_W01000_1_S6/kaiju_M0000N000ENE_W01000_1_S6_kairep.summary_genus


    #print("input files: {}".format(A))

    total_dataset      = {}  #{class: {file: {name: count}}}
    total_dataset["D"] = {}  
    total_dataset["P"] = {}  
    total_dataset["C"] = {}
    total_dataset["O"] = {}
    total_dataset["F"] = {}
    total_dataset["G"] = {}  

    for input_file in A:
        sample_base = os.path.basename(input_file)
        #basename="_".join(basename.split(".")[0].split("_")[1:4])  #kaiju_MC_W01000_1_kairep.summary_genus -> MC_W01000_1
        #sample      = sample_base.lstrip("NrEuk").rstrip("kairep.summary").strip("_")  #NrEuk_NSOL.hifi_kairep.summary -> NSOL.hifi
        sample      = sample_base.replace('NrEuk_', '').replace('_kairep.summary', '').replace('.hifi', '')  #NrEuk_NSOL.hifi_kairep.summary -> NSOL
        print("File: {} -> {}".format(sample_base, sample))

        filename_list      = {}
        filename_list["D"] = input_file+"_domain"
        filename_list["P"] = input_file+"_phylum"
        filename_list["C"] = input_file+"_class"
        filename_list["O"] = input_file+"_order"
        filename_list["F"] = input_file+"_family"
        filename_list["G"] = input_file+"_genus"

        #init
        total_dataset["D"][sample] = {} 
        total_dataset["P"][sample] = {} 
        total_dataset["C"][sample] = {} 
        total_dataset["O"][sample] = {} 
        total_dataset["F"][sample] = {} 
        total_dataset["G"][sample] = {} 

        for k,v in filename_list.items():
            with open(v,'r') as l: 
                #old format:  # 0.004745         8   Dictyoglomia; 
                #format: ../taxonomy/GORG_CM1_5m_5-0.99_RE/kaiju_GORG_CM1_5m_5-0.99_RE.out       0.164273        1817    1524249 Pseudohongiella

                for line in l : 
                    #print("{}: {}".format(v, line))
                    if "%"   in line : continue  
                    if "---" in line : continue 
                    
                    l=line.strip().split("\t")
                    if len(l)<5: continue 
                    if l[0] == "file": continue

                    count=l[2]
                    taxon=l[4]

                    if taxon=="":                     continue
                    #if "cannot be assigned" in taxon: continue
                    if "cannot be assigned" in taxon: #e.g., "cannot be assigned to a (non-viral) phylum"
                        taxon = "unclassified2"  #manual edit
                    #if "unclassified"       == taxon: continue
                    #if "Viruses"            == taxon: continue
                    if (k!="D") and ("Viruses" == taxon): continue #only cont when k=D
                    
                    total_dataset[k][sample][taxon]=int(count)

    #===================================================
    #make table for PCA 
    #===================================================
    taxonomy_table.make_table(total_dataset, Output_prefix, 0.00)  #no threshold
    taxonomy_table.make_table(total_dataset, Output_prefix, Other_threshold)
