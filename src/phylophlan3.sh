#!/bin/bash
#$ -m be
#$ -cwd
#$ -pe threads 6

function usage() {
    cat <<EOF
==================================================================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20200209
    History: 20210612
    History: 20230924 (change to use conda environment)
    History: 20250203
    - A wrapper of Phylophlan3 for phylogenetic analysis of prokaryotic genomes. 
    - Please be careful when run this script: Phylophlan3 will use huge machine power.
    - RAxML_bestTree.XXX.tre will be the final best tree.
    # - Qsub  unaveilable
    # - Nohup unaveilable
Require:
    conda environment (phylophlan)
Usage:
    conda activate phylophlan
    this.sh gene/genome_dir fileFileType[prot/nucl] speed[accurate/fast] diversity[low/medium/high]  [thread=6]
Option:
    gene/genome_dir    contain *.faa/fna files. 
                       Genome or Gene files are acceptable.
    fileFileType       prot  :protein
                       nucle :genome
    speed              [accurate/fast]
    diversity          [low(~genus)/medium(order-class)/high(phylum-)]
    thread             int
Install:
    conda create -n  phylophlan -c bioconda phylophlan=3.1.1  # python=3.8
    #phylophlan -d phylophlan --databases_folder ${HOME}/database/phylophlan --verbose
    #wget http://cmprod1.cibio.unitn.it/databases/PhyloPhlAn/phylophlan.tar ${HOME}/database/phylophlan
    -to make an database, you need to run the script at least one time in the gate server allowing data download. 
==================================================================================================================================================================================
EOF
    return 0
}   

#----------------------------------------------------
threads=6
phylophlan_dir=../phylophlan
phylophlan_config_dir=../phylophlan/configs
phylophlan_database=${HOME}/database/phylophlan

source ${HOME}/miniconda3/etc/profile.d/conda.sh
conda activate phylophlan
#----------------------------------------------------

if [ $# -lt 4 ]; then
    usage
    exit 1
fi

if [ $# -gt 4 ]; then
    threads=${5}
    echo "Threads: ${threads}"
fi

DIRNAME=${1}
BASE_DIRNAME=`basename ${DIRNAME}`
echo "Base dirname: ${BASE_DIRNAME}"

FileType=${2}
SpeedType=${3}
DiversityType=${4}
prefix=phylophlan3_${FileType}_${SpeedType}_${DiversityType}_${BASE_DIRNAME}
phylophlan_config=${phylophlan_config_dir}/config_${prefix}.cfg

# Make configuration folder
if [ ! -e ${phylophlan_config_dir} ]; then
    mkdir ${phylophlan_config_dir} -p
fi

# Make config file
echo "Create config files (${FileType} mode): ${phylophlan_config}"

if   [ ${FileType} == "prot" ]; then
    phylophlan_write_config_file --overwrite \
        -o ${phylophlan_config} \
        -d a \
        --db_aa   diamond  \
        --map_aa  diamond  \
        --map_dna diamond  \
        --msa     mafft    \
        --trim    trimal   \
        --tree1   fasttree \
        --tree2   raxml

elif [ ${FileType} == "nucl" ]; then
    phylophlan_write_config_file --overwrite \
        -o ${phylophlan_config} \
        -d a \
        --force_nucleotides \
        --db_aa   diamond  \
        --map_aa  diamond  \
        --map_dna diamond  \
        --msa     mafft    \
        --trim    trimal   \
        --tree1   fasttree \
        --tree2   raxml
else
    echo "Undefined FileType: ${FileType}"
    exit 0
fi


echo "make input dir and copy genome files"
tmp_input_dir="${phylophlan_dir}/input/${prefix}"
output_dir="   ${phylophlan_dir}/${prefix}"
log_file="     ${phylophlan_dir}/${prefix}/log.txt"

rm    ${tmp_input_dir} -r
mkdir ${tmp_input_dir} -p
mkdir ${output_dir}    -p

echo "rename sequence ID"
for f in ${DIRNAME}/*; do 
    echo ${f}

    prefix=`basename ${f}`  #Ct9H_90m
    prefix_base=`echo ${prefix}|rev|cut -f2- -d "."|rev`
    echo ${prefix_base}

    #prefix_ext=` echo ${prefix}|rev|cut -f1 -d "."|rev`
    if   [ ${FileType} == "prot" ]; then
        prefix_ext="faa"
    elif [ ${FileType} == "nucl" ]; then
        prefix_ext="fna"
    fi

    fasta_base_name=`basename ${f}`
    cat ${f} | sed -e "s/*//" | cut -f1 -d "#" | sed -e "s/^>/>${prefix}_/" > ${tmp_input_dir}/${prefix_base}.${prefix_ext}
done

#echo "init phylophlan"
#python2 phylophlan.py  --cleanall
#phylophlan --clean_all --diversity high

echo "prepare running command"
command="phylophlan -i ${tmp_input_dir} -o ${output_dir} \
                    -d phylophlan \
                    --diversity ${DiversityType} \
                    --${SpeedType}  \
                    -f ${phylophlan_config} \
                    --configs_folder ${phylophlan_config_dir} \
                    --nproc ${threads} \
                    --databases_folder ${phylophlan_database}"
                    #          --subsample phylophlan \
                    #--min_num_markers 10   \

#phylophlan -i ../genecall/SAR11/ --diversity high -d phylophlan -o ../phylophlan/tmp -f ../phylophlan/phylophlan_configs/config.cfg  --configs_folder ../phylophlan/phylophlan_configs/

if   [ ${FileType} == "nucl" ]; then
    command="${command} --force_nucleotides "
else
    command="${command}"
fi

#log file
command="${command} --verbose 2>&1 |tee ${log_file}" 
echo ${command}

#RUN
echo "run phylophlan"
eval ${command}

#clean up
rm ${output_dir}/tmp -r
rm ${output_dir}/*.aln
rm ${output_dir}/*.aln.reduced

#log
echo "output: ${output_dir}"
echo "[comment] ${output_dir}/RAxML_bestTree.XXX.tre will be the final best tree."

