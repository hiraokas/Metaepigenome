#!/usr/bin/env python
#coding: UTF-8

import sys 
import re
import os
import copy
import collections
from collections import defaultdict

def _help():
    print("""
==================================================================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created:  20200122
    History:  20210212
    History:  20230919
    - Make REBASE annotation from enzyme name list
    - informations are retrieved from bairoch file
Require:
    threads 1
Usage:
    python  this.py  < file.tsv
    cat XXX | python3 this.py 
Tips:
    cat ../blast/diamond_H.pylori_3401.cds_REBASE.tsv | cut -f2 | python3 MTase_getinfo_fromEnzymeNameList.py
==================================================================================================================================================================================
 """)

if __name__=='__main__':
    HomePath = os.environ['HOME']
    #bairoch_file    = "/home/G10800/hiraokas//data/database/REBASE/bairoch.912"
    bairoch_file    = "{}/database/REBASE/bairoch.305".format(HomePath)
    #print("# Used database: {}".format(bairoch_file))

    #get input names
    name_list = sys.stdin.readlines()

    if len(name_list)==0:
        print("# [ERROR] no inpu file name.")
        _help()
        exit()

    #road dataset
    #print("# roading bairoch file...")
    list_bairoch_dataset = {}  #{ID:{Key: value}} , Key=ET, AC, OS, ...
    with open(bairoch_file,'r') as l: 
        current_ID       = ""
        current_datadict = {}

        for line in l :  #PT   XmaIII
            if "//" in line:
                list_bairoch_dataset[current_ID]=current_datadict
                current_ID       = ""
                current_datadict = {}
                continue

            text = line.split()
            #text = re.split("\t", line)

            if len(text) < 2: continue

            bairoch_key   = text[0]
            bairoch_value = " ".join(text[1:])

            if bairoch_key == "CC": continue  #initial comments
            if bairoch_key == "ID": current_ID = bairoch_value

            current_datadict[bairoch_key] = bairoch_value

    #print("# list_bairoch_dataset({})".format(len(list_bairoch_dataset)))
    #print(list_bairoch_dataset)

    #get information
    for name in name_list:
        name = name.strip("\n")
        info_line=[]
        if name in list_bairoch_dataset.keys():
            bairoch_line=list_bairoch_dataset[name]

            #[name, enzyme_type, motif_sequence, modified_position, modification_base, ]
            enzyme_type       = bairoch_line["ET"]
            motif_sequence    = bairoch_line["RS"].split(",")[0]
            modified_position = bairoch_line["MS"].split("(")[0]               if "MS" in bairoch_line else "NA"
            modification_base = bairoch_line["MS"].split("(")[1].split(")")[0] if "MS" in bairoch_line else "NA"
            taxonomy          = bairoch_line["OS"]

            info_line=[ name, enzyme_type, motif_sequence, modified_position, modification_base, taxonomy]
        else:
            info_line=[name,"NA","NA","NA","NA"]
        
        print("\t".join(info_line))

 