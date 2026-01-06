#!/bin/sh
#$ -m be
#$ -cwd

function usage() {
    cat <<'EOF'
========================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20221025
    History: 20251008
    - This is a wrapper of CRISPRidentify to predict CRISPR system on given genome.
    - https://github.com/BackofenLab/CRISPRidentify
Require:
    conda environment (crispr_identify_env)
Usage:
    this target.fasta [threads=6]
Install:
    # CRISPRidentify
    wget https://github.com/BackofenLab/CRISPRidentify/archive/refs/tags/v1.2.1.tar.gz
    tar -xvf v1.2.1.tar.gz
    cd CRISPRidentify-1.2.1
    conda env create -f environment.yml

    # CRISPRcasIdentifier 
    cd ../
    wget https://github.com/BackofenLab/CRISPRcasIdentifier/archive/v1.1.0.tar.gz
    tar -xzf v1.1.0.tar.gz
    cd CRISPRcasIdentifier-1.1.0/
    wget https://drive.google.com/file/d/1YbTxkn9KuJP2D7U1-6kL1Yimu_4RqSl1/view?usp=sharing  #manual download
    wget https://drive.google.com/file/d/1Nc5o6QVB6QxMxpQjmLQcbwQwkRLk-thM/view?usp=sharing  #manual download

    cp  ~/workspace/software/CRISPRcasIdentifier-1.1.0/* ~/workspace/software/CRISPRidentify-1.2.1/tools/CRISPRcasIdentifier/CRISPRcasIdentifier -r

    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    # To make allow to work on qsub nodes in ES system, blast installed with CRISPRidentify should be removed and use local-installed blast 
    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    conda activate crispr_identify_env
    conda remove blast

    # run CRISPRidentify
    #qlogin -q cpu_I -l elapstim_req=8:00:00 -X
    conda activate crispr_identify_env
    export LD_LIBRARY_PATH=/S/home00/G3516/p0783/local/lib  #
    python ${HOME}/software/CRISPRidentify-1.2.1/CRISPRidentify.py --cpu 6 --input_folder ${HOME}/software/CRISPRidentify-1.2.1/TestInput --result_folder ../test --fasta_report True
    python CRISPRidentify.py --cpu 6 --file TestInputMultiline/MultilineFasta.fasta
========================================================================================================================================
EOF
    return 0
}   

#----------------------------------------------------------------------------------------------
CRISPRidentify="${HOME}/software/CRISPRidentify-1.2.1/CRISPRidentify.py"

#----------------------------------------------------------------------------------------------
if [ $# -lt 1 ]; then
    echo "Error: Please set two options; 'database path' and 'query file'"
    usage
    exit 1
fi

THREADS=6
if [ $# -gt 1 ]; then
    THREADS=${2}
fi
echo "Threads: ${THREADS}"

output_dir="../CRISPR_Tools/"
if [ ! -e ${output_dir} ]; then
    mkdir ${output_dir} -p
fi

source ${HOME}/miniconda3/etc/profile.d/conda.sh
conda activate crispr_identify_env

echo "===================================================="
echo $PATH
echo $LD_LIBRARY_PATH
which blastn
echo "===================================================="

str_filename=${1##*/}
str_filename_we=${str_filename%.*}
str_dirname=$(dirname ${1})

echo "Input file: ${str_filename_we}"
python ${CRISPRidentify} --file ${1} --result_folder ${output_dir}/CRISPRidentify_${str_filename_we} --cpu ${THREADS} --fasta_report True #--cas True --is_element True

#clean
rm ${output_dir}/CRISPRidentify_${str_filename_we}/*__whole_genome_shotgun_sequence -r

exit 0

