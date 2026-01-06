#!/usr/bin/env python
#coding: UTF-8

import sys 
import re
import os
import glob
import copy
from bisect import bisect
import collections
import subprocess
import multiprocessing
import json

def _help():
    print("""
==================================================================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp  
    Created: 20171001
    History: 20210224 (Marine metaepigenome)
    History: 20230530 (Pyroly epigenome)
    History: 20230918 (HotSpring)
    History: 20251225
    - Making DNA modethylated ratios by motif vs. genomeID table for heatmap/pca analysis.
    - threads = 10 (for seqkit)
Input Filename format:
    filename: sample.fa
    gff:      sample.motifs.gff
Input file format:
    motif list:
        motif   position    modification
        AATT    1   m6A
        ...
Usage:
    this.sh  motif_list.tsv  genome_file_path  prefix  motif.gff [motif.gff2, motif.gff3, ...]
Output format:
    table_for_PCA and others
Eep:
    python3 gff_ModificationMotifPresence_table.py  ../motif_heatmap/motif_set_1.tsv ../metabat/genomeAll_rename2/  XXXXX  ../modification/*_motifs.gff 
==================================================================================================================================================================================
 """)

motif_identificationQv_threthold=00
#motif_identificationQv_threthold=10
#motif_identificationQv_threthold=20

output_dir             = "../motifHeatmap"
working_dir            = "../motifHeatmap/work"
#genome_file_path       = "../metabat/genomeAll/"
#genome_file_path       = "../ViralGenome/"
#modification_type_list = ["m4C", "m5C", "m6A", "modified_base"]
threads = 10

#------------------------------------------------------------------------------------
def _list_dict():  return collections.defaultdict(list)
def _int_dict():   return collections.defaultdict(int)
def _float_dict(): return collections.defaultdict(float)
def _dict_dict():  return collections.defaultdict(lambda:collections.defaultdict(dict))

def _count_GC(seq):    
    return seq.count('G') + seq.count('C')

def _write_json(filepath, data):
    textdata = json.dumps(data)
    with open(filepath,'w') as f: 
        f.write(textdata) 

def _read_json(filepath):
    with open(filepath,'r') as f:  #biwa_65m_Cluster4       biwa_65m_tig00012541
        data = f.read()
    dictdata = json.loads(data)
    return dictdata

#------------------------------------------------------------------------------------
def contig_bin_perse(filename):
    contig_bin={}  #{contig:bin}
    with open(filename,'r') as f:  #biwa_65m_Cluster4       biwa_65m_tig00012541
        for line in f: 
            #print(line)
            texts=line.split()
            contig_bin[texts[1]]=texts[0]
    return contig_bin

#------------------------------------------------------------------------------------
## ? GAATC in GANTC
#------------------------------------------------------------------------------------
def conv_motif(ref):
    result = []
    degeneracy_list={
        "A":["A"],
        "T":["T"],
        "C":["C"],
        "G":["G"],
        "R":["A", "G"],
        "M":["A", "C"],
        "W":["A", "T"], 
        "S":["C", "G"],   
        "Y":["C", "T"],
        "K":["G", "T"], 
        "H":["A", "T", "C"], 
        "B":["G", "T", "C"],  
        "D":["G", "A", "T"],
        "V":["A", "C", "G"], 
        "N":["A", "C", "G", "T"]
    } 
    for i in ref: 
        result.append(degeneracy_list[i])
    return result

def match_seq(query, ref):
    if len(query)!=len(ref): return False
    conv_ref=conv_motif(ref)
    
    for i in range(0, len(query)): 
        if not query[i] in conv_ref[i]:
            return False

    return True

#------------------------------------------------------------------------------------
# counted up motifs on all genome
#------------------------------------------------------------------------------------
#def get_motif_count_genome(filename):
#    contig_motif_count,contig_length= motif_gff_perse(filename)
#    motif_count_dict=_int_dict()
#    for contig_id,motif_datas in sorted(contig_motif_count.items()):#{contig: {ModType_ModPos{motif: count}}}
#        for ModType_ModPos, count in sorted(motif_datas.items()):
#            motif=ModType_ModPos.split("_")[0]
#            motif_count_dict[motif]+=count
#
#    return motif_count_dict  #{motif: count}}

#------------------------------------------------------------------------------------
#Load motif list used for analysis
#------------------------------------------------------------------------------------
def get_motif_from_file():
    target_motif_list=[]  #[[motif, position, type, format, count]]
    with open(target_motif_file,'r') as f:
        for line in f:   #CCGG  1   m4C CCGG(1,m4C) 90
            #print(line)
            line = line.split("#")[0]  #remove comments
            if line.strip()=="": continue
            if line.strip().split()[0]=="motif"       : continue  # header
            if line.strip().split()[0]=="motifString" : continue  # header
            if line.strip().split()[0]=="?"           : continue  # undefined motif sequence
            target_motif_list.append(line.strip().split())
    return target_motif_list

#------------------------------------------------------------------------------------
#convert genome ID 
#Ct9H_90m.P9.motifs.gff -> Ct9H_90m.P9
#P-SAGv0.4_xxx_NSOL_075.mask.fa -> P-SAGv0.4_xxx_NSOL_075
#------------------------------------------------------------------------------------
def convert_filename_to_genome_ID(filename):
    genome_ID = filename.split("/")[-1].rsplit(".",2)[0]
    print("Genome ID: {} : {}".format(filename, genome_ID))
    return genome_ID

#------------------------------------------------------------------------------------
# main
#------------------------------------------------------------------------------------
if __name__=='__main__':
    argvs  = sys.argv 
    if len(argvs)<4:
        print("[ERROR] no input file name.")
        _help()
        exit()

    target_motif_file  = argvs[1]
    genome_file_path   = argvs[2] 
    output_prefix      = argvs[3] 
    input_filelist_gff = argvs[4:]  #wilde card

    if len(input_filelist_gff)==0:
        print("No gff file!")
        _help()
        exit()

    if not os.path.isdir(genome_file_path):
        print("Please set genome directory!")
        _help()
        exit()   

    if not os.path.isdir(working_dir):
        os.makedirs(working_dir, exist_ok=True)

    target_motif_file_base      = target_motif_file.rsplit("/",1)[1].rsplit(".",1)[0]
    output_filename1            = "{}/ModMotifGenome_{}_{}_{}_count.matrix".format( output_dir, target_motif_file_base, output_prefix, motif_identificationQv_threthold)
    output_filename2            = "{}/ModMotifGenome_{}_{}_{}_ratio.tsv".format(    output_dir, target_motif_file_base, output_prefix, motif_identificationQv_threthold)
    output_filename3            = "{}/ModMotifGenome_{}_{}_{}_ratio.matrix".format( output_dir, target_motif_file_base, output_prefix, motif_identificationQv_threthold)
    #output_filename_motif_count ="../methylome/methylation_motif_cont.tsv"
    #output_filename_bin_contig  ="../methylome/methylation_bin_contig.tsv"

    print("road specific motifs used for analysis")
    target_motif_list = get_motif_from_file()
    print("target motifs: {}".format(target_motif_list))

    #get files from directory
    bin_contig_motif_data={}  #{bin{contig: {ModType_ModPos:{motif: count}}}}
    #print("input files: {}".format(len(input_filelist_gff)))

    #------------------------------------------------------------------------------------
    ## perse gff file (*_motifs.gff) outputed from BaseMod
    #------------------------------------------------------------------------------------
    def motif_gff_perse(filename):  #{contig: [[mod_type, contex], [mod_type, contex], ...]}
        global motif_identificationQv_threthold
        print("motif_gff_perse")
        print("  motif_identificationQv_threthold: {}".format(motif_identificationQv_threthold))
        print("  now: {}".format(filename))

        #contig_motif_count=collections.defaultdict(_float_dict) #{contig: {motif: count}}
        contig_contex_list=_list_dict() #{contig: [[mod_type, contex], [mod_type, contex], ...]}

        contig_length = {}
        count         = 0
        with open(filename,'r') as f:
            for line in f: 
                if len(line) == 0: continue

                if line.find("#")>-1:  ##sequence-region tig00000075 1 9063
                    texts = line.split(" ")
                    if texts[0]!="##sequence-region": continue
                    contig_length[texts[1]] = int(texts[3])
                else:
                    #context=GCTGACCGGGTAAGTTAAGGATCAGCGCCTGTTTGCGAATC;motif=TAHGGAB;coverage=76;IPDRatio=3.00;id=TAHGGAB;identificationQv=40
                    #coverage=83;context=ATAAAAAAATCCCCCCGAGCGGGGGGATCTCAAAACAATTA;IPDRatio=2.77
                    modif_type             = ""
                    motif_coverage         = ""
                    motif_context          = ""
                    motif_motif            = ""
                    motif_identificationQv = ""
                    
                    texts       = line.split()
                    contig_id   = texts[0]
                    modif_type  = texts[2]
                    motif_infos = texts[8].split(";")

                    for motif_info in motif_infos:
                        tags = motif_info.split("=")
                        if   tags[0] == "coverage":         motif_coverage         =     tags[1]
                        elif tags[0] == "context":          motif_context          =     tags[1]
                        elif tags[0] == "motif":            motif_motif            =     tags[1]
                        elif tags[0] == "identificationQv": motif_identificationQv = int(tags[1])

                    #if modif_type=="modified_base": 
                    #    continue
                    #if motif_identificationQv == "": 
                    #    continue  
                    if (modif_type != "modified_base") and (motif_identificationQv < motif_identificationQv_threthold): 
                        continue

                    #store
                    contig_contex_list[contig_id].append([modif_type, motif_context])
                    count+=1

        print("  contig:    {}".format(len(contig_contex_list)))
        print("  total mod: {}".format(count))
        return contig_contex_list

    #------------------------------------------------------------------------------------
    ## count up motif presence in gff files
    ## return {contig: {ModType_ModPos:{motif: ratio}}}
    #------------------------------------------------------------------------------------
    def get_modified_motif_in_gff_contig(filename, target_motif_list):
        #global modification_type_list
        contig_contex_list= motif_gff_perse(filename) #{contig: [[mod_type, contex], [mod_type, contex], ...]}
        contig_motif_count= {} #{contig:{ModType_ModPos{motif:count}}}

        for contig_id,modified_contex_data in sorted(contig_contex_list.items()):  #{contig: [[mod_type, contex], [mod_type, contex], ...]}
            #set all motifs
            contig_motif_count[contig_id]={}

            for modified_contex in modified_contex_data:  #[[mod_type, contex], [mod_type, contex], ...]
                #print(modified_contex)
                gff_line_mod_type = modified_contex[0]
                gff_line_contex   = modified_contex[1]

                #print(modified_contex)
                for data in target_motif_list:   #[motif position type]
                    target_motif             = data[0]
                    target_position          = data[1]
                    target_modtype           = data[2]
                    ModType_ModPos           = "{}:{}".format(target_modtype, target_position)
                    #print("target: {}: {}".format(ModType_ModPos, target_motif))

                    #init
                    if not ModType_ModPos in contig_motif_count[contig_id].keys():
                        contig_motif_count[contig_id][ModType_ModPos]=_int_dict()

                    #different modification type
                    if (gff_line_mod_type != target_modtype): 
                        #print("error1")
                        continue

                    #get sequence region from gff contex
                    gff_line_contex_ext   = gff_line_contex[20-(int(target_position)-1):20-(int(target_position)-1)+len(target_motif)]
                    #print("{} vs. {}".format(gff_line_contex_ext, target_motif))
                    if match_seq(gff_line_contex_ext, target_motif) == False: 
                        #print("NG: {}: {}".format(gff_line_contex_ext, target_motif))
                        continue

                    #if target_motif=="CTANNNNNNNNTTG":
                    #    print("ASSERTION!!!!!  {}: {}: {}".format(filename,gff_line_contex_ext,target_motif))
                    #print("{}, {}, {}: {}: {} ({})".format(contig_id,target_modtype,target_motif, gff_line_contex, gff_line_contex_ext, gff_line_mod_type))
                    contig_motif_count[contig_id][ModType_ModPos][target_motif]+=1

        #print
        print(contig_motif_count)
        return contig_motif_count

    #calculate each gff files
    for input_file in input_filelist_gff:
        #new bin name
        genome_ID         = convert_filename_to_genome_ID(input_file )
        prevworkfile_gff  = "{}/{}_{}_basemod.tsv".format(working_dir, target_motif_file_base, genome_ID)

        #retrieve or calculate 
        if os.path.isfile(prevworkfile_gff):
            print("load from previous calculation: {}".format(prevworkfile_gff))
            contig_motif_data = _read_json(prevworkfile_gff)
        else:
            print("newly calculate:{}".format(genome_ID))
            contig_motif_data = get_modified_motif_in_gff_contig(input_file, target_motif_list) #{contig: {ModType_ModPos:{motif: ratio}}}
            #output
            _write_json(prevworkfile_gff, contig_motif_data)

        #resist
        bin_contig_motif_data[genome_ID]=contig_motif_data   
    #print(bin_contig_motif_data)

    #------------------------------------------------------------------------------------
    #motif presence matrix by contig
    #CURRENTLY NOT WORK
    #------------------------------------------------------------------------------------
    def output_modified_motif_count_matrix_by_contig(filename, bin_contig_motif_data, target_motif_list):
        pass
#        output_data=[]
#        
#        #make header
#        header     = ["bin","contig"]
#        motif_list = []
#        for motif_data in target_motif_list:
#            target_motif             = motif_data[0]
#            target_position          = motif_data[1]
#            target_modtype           = motif_data[2]
#            ModType_ModPos = "{}:{}".format(target_modtype, target_position)
#            motif_itemName = "{}:{}:{}".format(target_modtype, target_position, target_motif)
#
#            motif_list.append(motif_itemName)
#
#        for motif_itemName in sorted(motif_list):
#            header.append(motif)
#
#        output_data.append(header)
#
#        #set data
#        for bin_id, contig_data in sorted(bin_contig_motif_data.items()):  #{bin{contig: {ModType_ModPos:{motif: count}}}}
#            for contig, modification_data in sorted(contig_data.items()):  #    {contig: {ModType_ModPos:{motif: count}}}
#                for ModType_ModPos, motif_data in sorted(modification_data.items()):  #  {ModType_ModPos:{motif: count}}
#                    line=[bin_id, contig]
#                    for ModType_ModPos, count in sorted(motif_data.items()):
#                        line.append(str(count))
#                    output_data.append(line)
#
    #    #output data
    #    with open(filename,'w') as f: 
    #        for line in output_data:
    #            f.write("\t".join(line)+"\n") 
    #    f.close()
    #    print("output: {}".format(filename))

    #------------------------------------------------------------------------------------
    #motif presence matrix by genome
    #input   {bin: {contig: {ModType_ModPos: {motif: count}}}}
    # return {bin: {ModType_ModPos: {motif: count}}}
    #------------------------------------------------------------------------------------
    def Convert_ModifiedMotifCountMatrix_ByContig2ByGenome(bin_contig_motif_data, target_motif_list):
        #data convert from 'by contig' to 'by genome'
        bin_motif_data={}  #{bin: {ModType_ModPos: {motif: count}}}
        for bin_id, contig_data in bin_contig_motif_data.items():  #{bin: {contig: {ModType_ModPos: {motif: count}}}}

            #init
            bin_motif_data[bin_id]={}

            #count up
            for contig, moditifation_data in contig_data.items():  #   contig: {ModType_ModPos:{motif: count}}}
                for ModType_ModPos, motif_data in moditifation_data.items():  #{ModType_ModPos: {motif: count}}

                    #init
                    if not ModType_ModPos in bin_motif_data[bin_id].keys():
                        bin_motif_data[bin_id][ModType_ModPos]=_int_dict()

                    #count up
                    for motif, count in motif_data.items():  #{motif: count}
                        bin_motif_data[bin_id][ModType_ModPos][motif]+=count

        return bin_motif_data

    #------------------------------------------------------------------------------------
    # file output
    #bin    modification_type   AATT    ACAAA   AGCT    BAAAA   CAAAT   CATG    CCATC   CCNGG   CCSGG   CGCG    CTAG    CTAG    CTCC    GAAAC   GANTC   GATC    GATC    GATC    GATCC   GATGG   GAWTC   GCGC    GCWGC   GGHCC   GGWCC   GTAC    GTAC    GTNAC   GTNNAC  GTWAC   RGCY    RGCY    TGNNCA  TSAC    TTAA    VATB    YGCB    YGCYGC
    #CM1_200m.P1 m4C 85  37  23  14  24  166 48  19  53  18  6   19  158 210 7   48  158 0   0   0   0   0   0   0   24  0   0   0   48  0   19  0   0   0   0   0   0   0
    #CM1_200m.P1    m5C 0   0   0   0   0   0   10  0   0   0   0   0   39  0   0   10  39  0   0   0   0   0   0   0   0   0   0   0   10  0   0   0   0   0   0   0   0   0
    #CM1_200m.P1 m6A 0   0   0   0   4   0   130 0   0   0   0   10  0   0   0   130 0   48  3   26  9   9   16  8   4   0   32  26  130 32  10  10  4   5   5   34  21  356
    #------------------------------------------------------------------------------------
    def Output_ModifiedMotifCountMatrix_ByGenome(filename, bin_motif_data, target_motif_list):
        output_data=[]

        #make header
        header     = ["bin", "modification_type"]
        motif_list = []

        for motif_data in target_motif_list:
            target_motif = motif_data[0]
            header.append(target_motif)

        output_data.append(header)

        #data formatting
        for bin_id, modification_data in sorted(bin_motif_data.items()):  #  {bin: {ModType_ModPos: {motif: count}}}
            for ModType_ModPos, motif_data in sorted(modification_data.items()):  #{ModType_ModPos: {motif: count}}
                
                modification_type     = ModType_ModPos.split(":")[0]
                modification_position = ModType_ModPos.split(":")[1]
                line=[bin_id, modification_type]

                for motif_tuple in target_motif_list: 
                    line.append(str(motif_data[motif_tuple[0]]))
                output_data.append(line)

        #output data
        with open(filename,'w') as f: 
            for line in output_data:
                f.write("\t".join(line)+"\n") 
        f.close()

    #convert
    bin_motif_data = Convert_ModifiedMotifCountMatrix_ByContig2ByGenome(bin_contig_motif_data, target_motif_list)   #{bin{contig: {ModType_ModPos:{motif: count}}}}
    print(bin_motif_data)

    #output
    Output_ModifiedMotifCountMatrix_ByGenome(output_filename1, bin_motif_data, target_motif_list)
    print("Convert_ModifiedMotifCountMatrix_ByContig2ByGenome output: {}".format(output_filename1))


    #------------------------------------------------------------------------------------
    #get_genome_filepath_from_input_gff
    #------------------------------------------------------------------------------------
    def get_genome_filepath_from_input_gff(filepath):
        global genome_file_path

         #  bowtie2_wtdbg2_PC_Ct9H_90m.5-0.99.ccs_100m.ctg_KM1907-Ct9H-W0090PB_S2_L001_R1_sorted.bins.9_motifs.gff -> 
         #  bowtie2_wtdbg2_PC_Ct9H_90m.5-0.99.ccs_100m.ctg_KM1907-Ct9H-W0090PB_S2_L001_R1_sorted.bins.9.fa
        #input_filename_base   = filepath.split("/")[-1].rsplit("_", 1)[0] 


        #pbmm2_CM1_5m.V143_CM1_5m_subreads_RE_sorted_motifs.gff -> CM1_5m.V143.fa
        #input_filename_base   = "_".join(filepath.split("/")[-1].split("_")[1:3]) 

        #CM1_5m.P35_motifs.gff -> CM1_5m.P35.fa
        #input_filename_base   = filepath.split("/")[-1].rsplit("_",1)[0]
        genomeID = convert_filename_to_genome_ID(filepath)

        input_filename_genome = "{}/{}.fa".format(genome_file_path, genomeID)

        print(input_filename_genome)
        return input_filename_genome

    #------------------------------------------------------------------------------------
    #get motif presence using seqkit by contig
    #------------------------------------------------------------------------------------
    def get_motif_presence_on_contig(target_motif_list):
        contig_motif_presence_count=_dict_dict()  #{contig: {motif: presence}}
        for input_file in input_filelist_gff:
            input_filename_genome = get_genome_filepath_from_input_gff(input_file)
            #seqkit
            for motif_tuple in target_motif_list:  #[motif position type]
                #seqkit locate -idp GCWGC ../metabat/Final_20171102/metabat_canu_biwa_5m_1+2.ccs_PC_500m.3.fasta |cut -f1|uniq -c
                #   5246 tig00000839
                cmd = "seqkit locate -idp {} {} --threads {} | cut -f1 | uniq -c".format(motif_tuple[0], input_filename_genome, threads)
                re  = subprocess.check_output(cmd,  shell=True).decode("utf8")
                print(cmd)
                print(re.split())
                r = re.split()
                contig_presence_count={}  #{contig: presence}
                for i in range(0, len(r), 2):
                    if r[i+1]=="seqID": continue
                    #print(r[i+1])
                    contig_motif_presence_count[r[i+1]][motif_tuple[0]]=int(r[i])

        return contig_motif_presence_count

    #------------------------------------------------------------------------------------
    #seqkit command
    #------------------------------------------------------------------------------------
    def parallel_seqkit(input_file):
        results = {}

        #../metabat/genome_all/bowtie2_hypoShort_hypoCCS_wtdbg2_ONT_CM1_5m_ONT_1000m.ctg_KM1907-CM1-W0005PB_S1_L001_R1_sorted.bins.10.fa
        input_filename_genome = get_genome_filepath_from_input_gff(input_file)
        #genome_ID             = convert_filename_to_genome_ID(     input_file)

        #seqkit
        for motif_tuple in target_motif_list:  #[motif position type]
            #seqkit locate -idp GCWGC ../metabat/Final_20171102/metabat_canu_biwa_5m_1+2.ccs_PC_500m.3.fasta |cut -f1|uniq -c
            #   5246 tig00000839
            cmd = "seqkit locate -idp {} {} --threads {} | tail -n +2 | wc -l".format(motif_tuple[0], input_filename_genome, threads)
            re  = subprocess.check_output(cmd,  shell=True).decode("utf8")
            print(cmd)
            print(re.split())
            r = re.split()

            #genome_motif_presence_count[genome_ID][motif_tuple[0]]=int(r[0])
            results[motif_tuple[0]] = int(r[0])

        return results

    #------------------------------------------------------------------------------------
    #convert motif presence data from contig to genome
    #------------------------------------------------------------------------------------
    def get_motif_presence_on_genome():  #{genome: {motif: presence}}
        genome_motif_presence_count=_dict_dict() 

        # #with multiprocessing.Pool(8) as pool:
        # #    args=[(i,genome_motif_presence_count) for i in input_filelist_gff ]
        # #    print(args)
        # #    pool.map(parallel_seqkit, args)

        # for input_file in input_filelist_gff:
        #     parallel_seqkit(input_file, genome_motif_presence_count)
        
        #     #p = multiprocessing.Process(target=parallel_seqkit, args=(input_file))
        #     #p.start() 
        #     #p.join() 

        # #    with Pool(processes=8) as pool:
        # #        pool.map(parallel_seqkit, input_file)


        for input_file in input_filelist_gff:
            #new bin name
            genome_ID           = convert_filename_to_genome_ID(input_file )
            prevworkfile_seqkit = "{}/{}_{}_seqkit.tsv".format(working_dir, target_motif_file_base, genome_ID)

            #retrieve or calculate 
            if os.path.isfile(prevworkfile_seqkit):
                print("retrieve from previous calculation: {}".format(prevworkfile_seqkit))
                MotifPresenceOnGenome = _read_json(prevworkfile_seqkit)
            else:
                print("newly calculate:{}".format(genome_ID))
                MotifPresenceOnGenome = parallel_seqkit(input_file)
                #output
                _write_json(prevworkfile_seqkit, MotifPresenceOnGenome)

            genome_motif_presence_count[genome_ID] = MotifPresenceOnGenome

        return genome_motif_presence_count


    print("get_motif_presence_on_genome")
    genome_motif_presence_count = get_motif_presence_on_genome()
    #print(genome_motif_presence_count.keys())
    
    #------------------------------------------------------------------------------------
    #calculate ratios for each contig
    #------------------------------------------------------------------------------------
    def calculate_presence_ratio_by_contig(bin_contig_motif_data):  
        bin_contig_motif_ratio = {}  #{bin{contig: {ModType_ModPos: {motif: count}}}}
        for bin_id, contig_data in sorted(bin_contig_motif_data.items()):  #{bin{contig: {ModType_ModPos: {motif: count}}}}
            bin_contig_motif_ratio[bin_id] = {}
            for contig_id, modification_data in sorted(contig_data.items()):  #{contig{ModType_ModPos: {motif: count}}}
                bin_contig_motif_ratio[bin_id][contig] = {}
                for ModType_ModPos, motif_data in sorted(modification_data.items()):  #{ModType_ModPos: {motif: count}}
                    #modification_type     = ModType_ModPos.split(":")[0]
                    #modification_position = ModType_ModPos.split(":")[1]

                    bin_contig_motif_ratio[bin_id][contig][ModType_ModPos] = {}
                    for motif, count in sorted(motif_data.items()):
                        
                        # no motif present on the contig
                        if motif not in contig_motif_presence_count[contig].keys():  #{motif: count}
                            bin_contig_motif_ratio[bin_id][contig][ModType_ModPos][motif]=0
                            continue

                        #sum up 
                        presence   = contig_motif_presence_count[contig][motif]
                        ratio      = count/presence
                        bin_contig_motif_ratio[bin_id][contig][ModType_ModPos][motif]=ratio

        return bin_contig_motif_ratio

    #------------------------------------------------------------------------------------
    #calculate ratios of motified motifs on each genome
    #also, make output file
    #in:  #{genome: {motif: presence}}
    #in:  #{bin: {ModType_ModPos: {motif: count}}}
    #in:  #[motif position type]
    #out: #{bin{ModType_ModPos : {motif: ratio}}}
    #------------------------------------------------------------------------------------
    def calculate_presence_ratio_by_genome(filename, genome_motif_presence_count, bin_motif_data, target_motif_list): 
        #output
        output_data=[]
        header     = ["bin", "modification_type", "modification_position", "motif", "count","presence", "ratio"]
        output_data.append(header)

        genome_motif_ratio = _dict_dict()  #{bin: {ModType_ModPos: {motif: count}}}
        for motif_tuple in target_motif_list:   #[motif position type]
            #print(motif_tuple)
            target_motif                 = motif_tuple[0]
            target_modification_position = motif_tuple[1]
            target_modification_type     = motif_tuple[2]

            ModType_ModPos="{}:{}".format(target_modification_type, target_modification_position)

            for bin_id, modification_data in sorted(bin_motif_data.items()):   #{bin: {ModType_ModPos: {motif: count}}}
                #for ModType_ModPos, motif_data in sorted(modification_data.items()):  #{ModType_ModPos: {motif: count}}
                #    modification_type     = ModType_ModPos.split(":")[0]
                #    modification_position = ModType_ModPos.split(":")[1]
                #    #print(target_motif)
#
#                    if modification_type != target_modification_type:
#                        continue

                count     = modification_data[ModType_ModPos][target_motif] if  ModType_ModPos in modification_data.keys() else 0
                presence  = genome_motif_presence_count[bin_id][target_motif]
                if presence==0:  #no motif sequence presented in genome
                    ratio = "NA"
                else:
                    ratio = count/presence

                #print("bin: {},\tmodification_type: {},\tmodification_position: {},\ttarget_motif: {},\tcount: {},\tpresence: {},\tratio: {}".format(\
                #        bin_id, target_modification_type, target_modification_position, target_motif, count, presence, ratio))
                line  = [bin_id, target_modification_type, target_modification_position, target_motif, str(count), str(presence), str(ratio)]
                output_data.append(line)
                print("\t".join(line))

                genome_motif_ratio[bin_id][ModType_ModPos][target_motif]=ratio
        
        #output data
        with open(filename,'w') as f: 
            for line in output_data:
                f.write("\t".join(line)+"\n") 
        f.close()
        print("output: {}".format(filename))

        return genome_motif_ratio

    print("calculate_presence_ratio_by_genome")
    bin_motif_ratio = calculate_presence_ratio_by_genome(output_filename2, genome_motif_presence_count, bin_motif_data, target_motif_list)
    print("output_genome_motif_ratio_list: {}   ".format(output_filename2))
    #print(bin_motif_ratio)


    #------------------------------------------------------------------------------------
    #output
    #in: filename
    #in: #{bin{ModType_ModPos : {motif: ratio}}}
    #in:  #[motif position type]
    #out: [bin_id mod_type position motif ratio]
    #------------------------------------------------------------------------------------
    # def output_genome_motif_ratio_list(filename,  bin_motif_ratio, target_motif_list): 
    #     output_data=[]
        
    #     #make header
    #     header     = ["bin", "modification_type", "modification_position", "motif", "ratio"]
    #     output_data.append(header)

    #     for target_motif_data in target_motif_list:   #[motif position type]
    #         target_motif             = target_motif_data[0]
    #         target_position          = target_motif_data[1]
    #         target_modification_type = target_motif_data[2]
    #         ModType_ModPos="{}:{}".format(target_modification_type, target_position)

    #         for bin_id, modification_data in sorted(bin_motif_ratio.items()):  #{bin {ModType_ModPos : {motif: ratio}}}

    #             ratio = modification_data[ModType_ModPos][target_motif]
    #             line  = [bin_id, target_modification_type, target_position, target_motif, str(ratio)]

    #             output_data.append(line)
    #             #print(line)

    #     #output data
    #     with open(filename,'w') as f: 
    #         for line in output_data:
    #             f.write("\t".join(line)+"\n") 
    #     f.close()
    #     print("output: {}".format(filename))

    #------------------------------------------------------------------------------------
    #output
    #in: filename
    #in: #{bin{ModType_ModPos : {motif: ratio}}}
    #in:  #[motif position type]
    #out: [bin_id motif(mod_type) ratio1 ratio2 ratio3... ]
    #------------------------------------------------------------------------------------
    def output_genome_motif_ratio_matrix(filename, data, target_motif_list): 
        output_data=[]
        
        #make header
        header     = ["bin" ]
        for motif_data in target_motif_list:  ##[[motif, position, type]]
            target_motif_str = ("{}({},{})".format(motif_data[0], motif_data[1], motif_data[2]))
            header.append(target_motif_str)
        output_data.append(header)

        for bin_id, modification_data in sorted(data.items()):  #{bin {ModType_ModPos : {motif: ratio}}}
            line  = [bin_id]

            for target_motif_data in target_motif_list:   #[motif position type]
                target_motif             = target_motif_data[0]
                target_position          = target_motif_data[1]
                target_modification_type = target_motif_data[2]
                ModType_ModPos="{}:{}".format(target_modification_type, target_position)

                ratio = 0
                if ModType_ModPos in modification_data.keys() and target_motif in modification_data[ModType_ModPos].keys(): 
                    ratio = modification_data[ModType_ModPos][target_motif]
                line.append(str(ratio))
                
            output_data.append(line)

        #output data
        with open(filename,'w') as f: 
            for line in output_data:
                f.write("\t".join(line)+"\n") 
        f.close()
        print("output: {}".format(filename))

    #output
    output_genome_motif_ratio_matrix(output_filename3, bin_motif_ratio, target_motif_list)
    print("output_genome_motif_ratio_matrix: {}".format(output_filename3))

    #print("dummy error.")
    print("All done.")
    exit()










    # #------------------------------------------------------------------------------------
    # #top annotation barplot (motif count)
    # #------------------------------------------------------------------------------------
    # def output_motif_count_by_genome(output_filename):
    #     total_motif_count=_int_dict()
    #     for motif,count in biwa_5m_motif_count.items():
    #         total_motif_count[motif]+=count
    #     for motif,count in biwa_65m_motif_count.items():
    #         total_motif_count[motif]+=count

    #     with open(output_filename_motif_count,'w') as f: 
    #         for motif,count in sorted(total_motif_count.items()):
    #             #print(line)
    #             f.write(motif+"\t"+str(count)+"\n") 
    #     f.close()
    #     print("output: "+output_filename_motif_count)

    # #------------------------------------------------------------------------------------
    # #right annotated heatmap (contig-bin)
    # #------------------------------------------------------------------------------------
    # def output_motif_count_by_genome(output_filename):
    #     output_data=[]  #contigs (10000) x bins (17)
    #     All_bins=[  "biwa_5m_Cluster1",
    #             "biwa_5m_Cluster2",
    #             "biwa_5m_Cluster3",
    #             "biwa_5m_Cluster4",
    #             "biwa_5m_Cluster5",
    #             "biwa_5m_Cluster6",
    #             "biwa_5m_Cluster7",
    #             "biwa_5m_Cluster8",
    #             "biwa_5m_Cluster9",
    #             "biwa_5m_Cluster10",
    #             "biwa_5m_Cluster11",
    #             "biwa_5m_Cluster12",
    #             "biwa_5m_Cluster13",
    #             "biwa_65m_Cluster1",
    #             "biwa_65m_Cluster2",
    #             "biwa_65m_Cluster3",
    #             "biwa_65m_Cluster4"]
    #     header=["contig"]+All_bins
    #     print(header)
    #     output_data.append(header)

    #     #change contig ID
    #     total_contig_list=[]
    #     for contig in biwa_5m_contig_motif_count.keys():
    #         total_contig_list.append("biwa_5m_"+contig)
    #     for contig in biwa_65m_contig_motif_count.keys():
    #         total_contig_list.append("biwa_65m_"+contig)

    #     for contig,bins  in sorted(contig_bin_maptable.items()):  # biwa_65m_tig00012541 biwa_65m_Cluster4 
    #         #print(contig)
    #         if contig not in total_contig_list: continue
    #         #print("pass: "+contig)
    #         line=[]
    #         for binID in All_bins:
    #             flag="1" if bins==binID else "0"
    #             line.append(flag)
    #         output_data.append([contig]+line)
    #     #print(output_data)

    #     with open(output_filename_bin_contig,'w') as f: 
    #         #f.write("\t".join(header))
    #         for line in output_data:
    #             print(line)
    #             f.write("\t".join(line)+"\n")

    #         #f.write(motif+"\t"+str(count)+"\n") 
    #     f.close()
    #     print("output: "+output_filename_bin_contig)


    
