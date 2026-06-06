#!/usr/bin/env python
#coding: UTF-8

import os.path
import sys
import re
import collections
import subprocess

def _help():
    print("""
==================================================================================================================================================================================        
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20191228
    History: 20210802
    History: 20211127
    History: 20230502 (bairoch305)
    History: 20240301 (corresp. to bairoch402, but not use)
    History: 20260212 (update REBASE 20251028)
    - Count up each type of MTases
Require:
    seqkit
Input File format:
    Blast output against REBASE
Usage: 
    python3 gene.faa blast.tsv 
Tips:
    python3 MTase_count.py ../genecall/HiFi_all/CM1_5m.HiFi.faa       ../blast/HiFi_REBASE/all_CM1_5m_REBASE.tsv
    python3 MTase_count.py ../genecall/HiFi_all/CM1_200m.HiFi.faa     ../blast/HiFi_REBASE/all_CM1_200m_REBASE.tsv
    python3 MTase_count.py ../genecall/HiFi_all/Ct9H_90m.HiFi.faa     ../blast/HiFi_REBASE/all_Ct9H_90m_REBASE.tsv
    python3 MTase_count.py ../genecall/HiFi_all/Ct9H_300m.HiFi.faa    ../blast/HiFi_REBASE/all_Ct9H_300m_REBASE.tsv

------------------------------------------------------------------------------
#Preparation

1. get enzymatic type list (EnzymeType, RecSeq)
    past: cd ~/database/REBASE
    past: wget ftp://ftp.neb.com/pub/rebase/protein_gold_seqs.txt
    # Also use ffftp for downloading files via FTP
    mv protein_gold_seqs.txt protein_gold_seqs_20240301.txt
    cat protein_gold_seqs_20251028.txt | grep ">" | grep "<" -v | cut -c9- > ProteinGoldSeqsID_20251028.tsv
2. get MTase list (modification position and type)  
    #### [[[[manuary downloaded]]]] list from http://rebase.neb.com/cgi-bin/mflatlist 
    get allmeths.txt file from FTP site

==================================================================================================================================================================================        
    """)

        
#http://qiita.com/shrkw/items/6f872ece6b29e160c0ec
def _int_dict():
    return collections.defaultdict(int)

def _dict_dict():
    return collections.defaultdict(dict)

        
if __name__=='__main__':

    HomePath = os.environ['HOME']

    #definition
    filepath_bairoach= "{}/database/REBASE/bairoch.601.txt".format(HomePath)
    filepath_Enzyme  = "{}/database/REBASE/ProteinGoldSeqsID_20251028.tsv".format(HomePath)
    #filepath_MTase   = "{}/database/REBASE/MTaseModificationTypes_20230502.tsv".format(HomePath)
    filepath_MTase   = "{}/database/REBASE/allmeths_20251028.txt".format(HomePath)
        
    print("Used database=============================================================================")
    print("{}: {}".format(filepath_bairoach, os.path.exists(filepath_bairoach)))
    print("{}: {}".format(filepath_Enzyme,   os.path.exists(filepath_Enzyme)))
    print("{}: {}".format(filepath_MTase,    os.path.exists(filepath_MTase)))
    print("==========================================================================================")
    
    def_RM_type = {"M1"  : "TypeI",
                   "RM1" : "TypeI",
                   "M2"  : "TypeII",
                   "RM2" : "TypeII",
                   "M3"  : "TypeIII",
                   "R1"  : "other",
                   "R2"  : "other",
                   "R2*" : "other",
                   "R3"  : "other",
                   "R4"  : "other",
                   "S"   : "other",
                   "M"   : "unknown",
                   "IE"  : "other",
                   "none": "other"
                  }
    def_RM_fuse = {"M1"  : "M",  # +"S"
                   "RM1" : "RM",
                   "M2"  : "M",
                   "RM2" : "RM",
                   "M3"  : "M",
                   "R1"  : "R",
                   "R2"  : "R",
                   "R2*" : "R",
                   "R3"  : "R",
                   "R4"  : "R",
                   "M"   : "M",
                   "IE"  : "R",
                   "S"   : "S",
                   "none": "none"
                  }
    #def_modification = {"6mA" : "m6A",
    #                    "5mC" : "m5C",
    #                    "N4mC": "m4C",
    #                    "?"   : "unknown"
    #                   }

    output_filepath="../MTase/summary/"
    if not os.path.isdir(output_filepath):
        os.makedirs(output_filepath)

    argvs = sys.argv 
    argc  = len(argvs)

    if argc<2:
        print("Error: Please set input file! ")
        _help()
        exit()
    
    gene_fasta_filepath = argvs[1]
    in_file             = argvs[2]

    def check_file(file):
        if not os.path.exists(file):
            print("[**Error**] File not exist: "+in_file)
            _help()
            return False
        return True
    if not check_file(in_file):           exit()
    #if not check_file(bairoach_filepath): exit()

        
    #==============================================================    
    #get number of gene
    #==============================================================    
    print("get gene number by seqkit")
    cmd = "seqkit stat {} ".format(gene_fasta_filepath)
    re  = subprocess.check_output(cmd,  shell=True).decode("utf8")
    print(cmd)
    #print(re.split())
    r  = re.split()
    gene_number=int(r[11].replace(',', ''))
    print("gene number: {}".format(gene_number))


    #==============================================================    
    # blasted file 
    #==============================================================    
    print("File: "+in_file)
    f = open(in_file)
    #blast_data={}  #{gene_id: [MTase_name, identity, e-value]}
    blast_data=[]  #[gene_id, MTase_name, identity, e-value]
    passed_count=0
    for line in f:  #m54023_191210_002144/4390978/ccs_12     I-SceVI 50.000  54      27      0       18      71      3       56      1.30e-10        60.1
        a           = line.split('	')  #tab
        gene_id     = a[0] 
        MTase_name  = a[1].strip() 
        identity    = a[2].strip() 
        evalue      = a[10].strip() 

        #use only the lowest e-value if multipl hit occurred
        # if gene_id in blast_data.keys():
        #     #print("passed: "+gene_id)
        #     passed_count+=1
        #     continue

        #blast_data[gene_id]=[MTase_name, identity, evalue]
        blast_data.append([gene_id, MTase_name, identity, evalue])

    f.close()

    print("Passed gene id count: {}".format(passed_count))
    print("blast_data: {}".format(len(blast_data)))


    #==============================================================    
    # load_ProteinGoldSeqsID dataset
    #==============================================================    
    def load_ProteinGoldSeqsID(filepath_Enzyme):
        print("roading ProteinGoldSeqsID file...")
        ProteinGoldSeqsID_dataset = _dict_dict()  #{ID:{Key: value}} , Key=ET, AC, OS, ...

        with open(filepath_Enzyme,'r') as l:
            for line in l :

                #M.Aav11297I     EnzType:Type I methyltransferase        RecSeq:GCAANNNNNTTA     Org#: 39224     OrgName: Avibacterium avium NCTC 11297  Source: NCTC 11297      GenBank:UGSP01000001    SeqLength:452   Locus:NCTC11297_01913 ProteinId:SUB24849.1    UniProt:A0A379ATE8
                text = line.strip().split("\t")

                #Enzyme_name   = text[0].split(" ")[0]                #HpyAXVIII (HpyAXVIIIA) (RM.HpyAXVIII)
                Enzyme_name_list   = [s.replace('(', '').replace(')', '') for s in text[0].split(" ")]        #HpyAXVIII (HpyAXVIIIA) (RM.HpyAXVIII) -> [HpyAXVIII, HpyAXVIIIA, RM.HpyAXVIII]

                #print(text)
                # Enzyme_type    = text[1].split(":")[1].strip()  #Type I methyltransferase
                # Enzyme_RecSeq  = text[2].split(":")[1].strip()
                # Enzyme_OrgName = text[4].split(":")[1].strip()
                
                item_data = {}
                for item in text[1:]:
                    item_key   = item.split(":")[0]
                    item_value = item.split(":")[1]
                    item_data[item_key]=item_value.strip()

                Enzyme_type = item_data["EnzType"]    
                RMType=""
                if   Enzyme_type == "control protein":                                RMType="none"
                elif Enzyme_type == "homing endonuclease":                            RMType="IE"
                elif Enzyme_type == "orphan methyltransferase":                       RMType="M"
                elif Enzyme_type == "Type I methyltransferase":                       RMType="M1"
                elif Enzyme_type == "Type I restriction enzyme":                      RMType="R1"
                elif Enzyme_type == "Type I restriction enzyme/methyltransferase":    RMType="RM1"
                elif Enzyme_type == "Type I specificity subunit":                     RMType="S"
                elif Enzyme_type == "Type II helicase domain protein":                RMType="none"
                elif Enzyme_type == "Type II methyl-directed restriction enzyme":     RMType="M1"
                elif Enzyme_type == "Type II methyltransferase":                      RMType="M2"
                elif Enzyme_type == "Type II nicking endonuclease":                   RMType="none"
                elif Enzyme_type == "Type II restriction enzyme":                     RMType="R2"
                elif Enzyme_type == "Type II specificity subunit":                    RMType="S"
                elif Enzyme_type == "Type IIG restriction enzyme/methyltransferase":  RMType="RM2"
                elif Enzyme_type == "Type III methyltransferase":                     RMType="M3"
                elif Enzyme_type == "Type III restriction enzyme":                    RMType="R3"
                elif Enzyme_type == "Type IV methyl-directed restriction enzyme":     RMType="R4"
                else:
                    print("WARNING:{}".format(Enzyme_type))
                
                for Enzyme_name in Enzyme_name_list:
                    #print("{}: {}".format(Enzyme_type, Type))
                    # ProteinGoldSeqsID_dataset[Enzyme_name]["ET"] = RMType
                    # ProteinGoldSeqsID_dataset[Enzyme_name]["RS"] = Enzyme_RecSeq
                    # ProteinGoldSeqsID_dataset[Enzyme_name]["OS"] = Enzyme_OrgName
                    ProteinGoldSeqsID_dataset[Enzyme_name]["ET"] = RMType
                    ProteinGoldSeqsID_dataset[Enzyme_name]["RS"] = item_data.get("RecSeq", "NA")
                    ProteinGoldSeqsID_dataset[Enzyme_name]["OS"] = item_data.get("OrgName", "NA")

        print("ProteinGoldSeqsID: {}".format(len(ProteinGoldSeqsID_dataset)))

        return ProteinGoldSeqsID_dataset


    #==============================================================    
    #abolished
    #load bairoch dataset
    #==============================================================    
    # def load_bairoch(filepath_bairoach):
    #     print("roading bairoch file...")
    #     bairoch_dataset = {}  #{ID:{Key: value}} , Key=ET, AC, OS, ...
    #     with open(filepath_bairoach,'r') as l:
    #         current_ID       = ""
    #         current_datadict = {} 

    #         for line in l :  #PT   XmaIII
    #             if "//" in line:
    #                 bairoch_dataset[current_ID]=current_datadict
    #                 current_ID       = ""
    #                 current_datadict = {}
    #                 continue

    #             text = line.split()
    #             if len(text) < 2: continue

    #             bairoch_key   = text[0]
    #             bairoch_value = text[1]

    #             if bairoch_key == "CC": continue  #initial comments
    #             #if bairoch_key == "ID": current_ID = bairoch_value.replace(".", "_")
    #             if bairoch_key == "ID": current_ID = bairoch_value

    #             current_datadict[bairoch_key] = bairoch_value
    #     print("bairoch_dataset: {}".format(len(bairoch_dataset)))

    #     return bairoch_dataset


    #==============================================================    
    # abolished
    # load bairoch dataset
    #==============================================================    
    # def load_MTaseModificationTypes(filepath_MTase, bairoch_dataset):  #{ID:{Key: value}} , Key=ET, AC, OS, ...
    #     print("roading MTaseModificationTypes file...")
    #     with open(filepath_MTase,'r') as l:
    #         current_ID       = ""
    #         MTase_type       = "?" 

    #         for line in l :  # <enz_name>M.AacDam

    #             line = line[1:].strip()
    #             if len(line) == 0: continue

    #             #print(line[1:2])
    #             if line[1:2] == "*": continue  #comment

    #             if line == ">":  #end of the item
    #                 #print("{}: {}".format(current_ID, MTase_type))
    #                 bairoch_dataset[current_ID]["MS"]=MTase_type
    #                 current_ID       = ""
    #                 MTase_type       = "?"
    #                 continue

    #             text  = line.split(">")
    #             #print(text)
    #             key   = text[0]
    #             value = text[1]

    #             if key == "enz_name":
    #                 current_ID = value

    #             if key == "meth_type":
    #                 #if   value == "N6A": MTase_type = "(6mA)"
    #                 #elif value == "C5" : MTase_type = "(5mC)"
    #                 #elif value == "N4" : MTase_type = "(N4mC)"
    #                 if   value == "6" : MTase_type = "(6mA)"
    #                 elif value == "5" : MTase_type = "(5mC)"
    #                 elif value == "4" : MTase_type = "(N4mC)"

    #     print("MTaseModificationTypes: {}".format(len(bairoch_dataset)))
    #     return bairoch_dataset


    #==============================================================    
    #load MTase informatin file (allmeths)
    #==============================================================    
    def load_allmeths(filepath_MTase, bairoch_dataset):
        print("roading allmeths file...")

        # <1>M.Kpn828304II
        # <2>S.KpnAATIV
        # <3>Klebsiella pneumoniae Kp_Goe_828304
        # <4>A.E. Zautner
        # <5>CGANNNNNNNNTGCC
        # <6>3(6),-4(6)
        # <7>
        # <8>Bohne, W., Bunk, B., Overmann, J., Gross, U., Zautner, A.E., Unpublished observations.
        # Zautner, A.E., Bunk, B., Pfeifer, Y., Sproer, C., Reichard, U., Eiffert, H., Scheithauer, S., Gross, U., Overmann, J., Bohne, W., (2017) J. Antimicrob. Chemother., vol. 72, pp. 2737-2744.

        with open(filepath_MTase,'r') as l:
            current_ID = source =  motif_sequence  = ""
            modification_format = "?" 

            for line in l :  
                line = line.strip()
                #print(line)
                if len(line) == 0:   continue  #blank line
                if line[0:1] != "<": continue  #not informative line

                lineID   = line[1:2]  # 1-8
                linedata = line[3:]
                if not lineID.isdigit(): continue
                
                translate_table=["ID", "PT","OS","NA","RS","MS","NA","RA"]
                key   = translate_table[int(lineID)-1]
                value = linedata
                #print("{}: {}".format(key, value))

                if key == "ID":
                    current_ID = value
                elif key == "OS":
                    source = value
                elif key == "RS":
                    motif_sequence = value
                elif key == "MS":
                    modification_format = value.split(",")[0].replace("(4)", "(Nm4C)").replace("(5)", "(m5C)").replace("(6)", "(m6A)")
                elif key == "RA":  #end of the item
                    #print("{}: {}".format(current_ID, modification_format))
                    bairoch_dataset[current_ID]["OS"] = source
                    bairoch_dataset[current_ID]["RS"] = motif_sequence
                    bairoch_dataset[current_ID]["MS"] = modification_format

                    #init
                    current_ID = source =  motif_sequence  = ""
                    modification_format = "?" 

        print("allmeths: {}".format(len(bairoch_dataset)))
        return bairoch_dataset


    #bairoch_dataset = load_bairoch(filepath_bairoch)
    bairoch_dataset = load_ProteinGoldSeqsID(     filepath_Enzyme)
    #bairoch_dataset = load_MTaseModificationTypes(filepath_MTase, bairoch_dataset)
    bairoch_dataset = load_allmeths( filepath_MTase, bairoch_dataset)
    


    #==============================================================    
    #counting each of MTase types
    #==============================================================    
    count_MTaseType        = _int_dict()
    count_EnzymeType       = _int_dict()
    count_ModificationType = _int_dict()
    #for gene_id, blast_elem_list in blast_data.items():
    for line in blast_data:
        gene_id         = line[0]
        blast_elem_list = line[1:3]

        #MTase_name=blast_elem_list[0].strip()
        MTase_name =line[1].strip()
        
        #S gene------------------------------------
        #print(MTase_name[0:2])
        if MTase_name.startswith("S.") :
            #print("SSSSSSSSSSSSSSSSSSSS")
            count_EnzymeType["S"] +=1
            continue

        #not registerd------------------------------------
        if MTase_name not in bairoch_dataset.keys():
            print("No data in bairoach: {}, reject.".format(MTase_name))
            continue

        #MTase------------------------------------
        bairoch_data=bairoch_dataset[MTase_name]

        #RM type
        if "ET" not in bairoch_data.keys(): 
            print("No ET: {}, continue.".format(MTase_name)); 
            item_type = "none"
        else:
            item_type = bairoch_data["ET"]  #M1, M2, M3, RM2,  ...
        RM_type = def_RM_type[item_type]
        RM_fuse = def_RM_fuse[item_type] 

        #modified base
        if "MS" not in bairoch_data.keys(): 
            print("No MS: {}, continue.".format(MTase_name)); 
            item_modification = "none"
        else:
            item_modification =  bairoch_data["MS"]  #4(6mA);, ?(5mC);, ?, ?;, ...
        
        if "(" in item_modification :
            #print(item_modification)
            #modification = def_modification[item_modification.split("(")[1].split(")")[0]] 
            modification = item_modification.split("(")[1].split(")")[0].strip()
        else :
            modification = "unknown"

        #RM system
        #if MTase_name.split(".")[1] in bairoch_dataset.keys():
        #    RM_system = "Yes" 
        #else:
        #    RM_system = "No"  #M.AatII <> AatII  #search all in bairoch dataset

        #count up if the gene should be MTase
        count_EnzymeType[RM_fuse]               +=1
        if RM_fuse in ["M", "RM"]:
            count_MTaseType[RM_type]            +=1
            count_ModificationType[modification]+=1

    #==============================================================    
    #convert count to ratio
    #==============================================================   
    def count2ratio(data, gene_number):
        result={}
        for k,v in data.items():
            result[k]= v/gene_number
        return(result)

    ratio_EnzymeType       = count2ratio(count_EnzymeType       , gene_number)
    ratio_MTaseType        = count2ratio(count_MTaseType        , gene_number)
    ratio_ModificationType = count2ratio(count_ModificationType , gene_number)

    #==============================================================    
    #output
    #==============================================================    
    output_prefix=output_filepath+os.path.basename(in_file)
    def output_dist(data, name):
        output_filename="{}_{}.tsv".format(output_prefix, name)

        f = open(output_filename,'w')

        #header
        f.write("\t".join(["key", "value"])+"\n")

        #body
        for k,v in sorted(data.items()):
            f.write(k+"\t"+str(v)+"\n")

        f.close()

        print("Output: {}".format(output_filename))


    output_dist(ratio_EnzymeType,       "Enzyme_type")
    output_dist(ratio_MTaseType,        "MTase_type")
    output_dist(ratio_ModificationType, "Modification_type")


    #==============================================================    
    # make details of each RM gene
    #==============================================================  
    annotation=[]
    for line in blast_data:
        gene_id    = line[0]
        MTase_name = line[1].strip()

        if MTase_name not in bairoch_dataset.keys():
            #not registerd------------------------------------
            print("No data in bairoach: {}, continue.".format(MTase_name))
            bairoch_data={}
            #continue
        else:
            #MTase------------------------------------
            bairoch_data=bairoch_dataset[MTase_name]
            #print(bairoch_data)

        #RM type
        if "ET" not in bairoch_data.keys(): 
            print("No ET: {}, continue.".format(MTase_name)); 
            item_type = "NA"
        else:
            item_type = bairoch_data["ET"]  #M1, M2, M3, RM2,  ...

        #recognition sequence
        if "RS" not in bairoch_data.keys(): 
            print("No RS: {}, continue.".format(MTase_name)); 
            item_sequence = "NA"
        else:
            item_sequence =  bairoch_data["RS"]  #CGTANNNNNGTC

        #modified base
        if "MS" not in bairoch_data.keys(): 
            print("No MS: {}, continue.".format(MTase_name)); 
            item_modification = "NA"
        else:
            item_modification =  bairoch_data["MS"]  #4(6mA);, ?(5mC);, ?, ?;, ...
        
        if "(" in item_modification :
            position     = item_modification.split("(")[0].strip()
            modification = item_modification.split("(")[1].split(")")[0].strip()
        elif "," in item_modification:
            position     = item_modification[0]
            modification = "NA"
        else:
            position     = "NA"
            modification = "NA"

        #source lineage
        if "OS" not in bairoch_data.keys(): 
            print("No OS: {}, continue.".format(MTase_name)); 
            item_sourcce = "NA"
        else:
            item_sourcce =  bairoch_data["OS"]  #Escherichia coli NCTC9777


        annotation_line=[gene_id, MTase_name, item_type, item_sequence, position, modification, item_sourcce]
        annotation.append(annotation_line)


    #==============================================================    
    #output
    #==============================================================    
    def output_dist(data):
        output_filename="{}_annotation.tsv".format(output_prefix)
        f = open(output_filename,'w')

        #body
        for line in data:
            f.write("\t".join(line)+"\n")
        f.close()

        print("Output: {}".format(output_filename))

    output_dist(annotation)


print("All done.")
