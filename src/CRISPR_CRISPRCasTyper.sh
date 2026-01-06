#!/bin/sh
#$ -m be
#$ -cwd

function usage() {
    cat <<'EOF'
========================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20250710
    History: 20251223
    - This is a wrapper of CRISPRCasTyper to predict CRISPR system.
    - https://github.com/Russel88/CRISPRCasTyper
Require:
    DB: ~/database/CRISPRCasTyper
    conda environment (cctyper2)
Usage:
    this target.fasta [mode=single(default)/meta] [threads=6]
Install:
    # conda install ---------------------------
    # conda create -n cctyper -c conda-forge -c bioconda -c russel88 cctyper blast=2.16  #s
    # conda activate cctyper 
    # conda install blast==2.16 -c biopython
    # cctyper my.fasta my_output --db  ${HOME}/database/CRISPRCasTyper

    # #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    # # To make allow to work on qsub nodes in ES system, blast installed with CRISPRidentify should be removed and use local-installed blast 
    # #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    # conda activate cctyper
    # conda remove blast

    # PIP install ---------------------------
    conda create -n cctyper2
    conda activate cctyper2
    python -m pip install cctyper
    python -m pip install cctyper --upgrade
    conda install -c bioconda minced
    python3 -m pip install "drawsvg~=1.9"  #should be downgraded

    # Download and unpack
    svn checkout https://github.com/Russel88/CRISPRCasTyper/trunk/data
    tar -xvzf data/Profiles.tar.gz
    mv Profiles/ data/
    rm data/Profiles.tar.gz
========================================================================================================================================
EOF
    return 0
}   

if [ $# -lt 1 ]; then
    echo "Error: Please set two options; 'database path' and 'query file'"
    usage
    exit 1
fi

THREADS=6
if [ $# -gt 2 ]; then
    THREADS=${3}
fi
echo "Threads: ${THREADS}"

source ${HOME}/miniconda3/etc/profile.d/conda.sh
conda activate cctyper2
export PATH=/S/home00/G3516/p0783/local/bin:${PATH}

echo "===================================================="
echo $PATH
echo $LD_LIBRARY_PATH
which blastn
echo "===================================================="

str_filename=${1##*/}
str_filename_we=${str_filename%.*}
str_dirname=$(dirname ${1})
echo "Input file: ${str_filename_we}"

output_dir="../CRISPR_Tools/CRISPRCasTyper_${str_filename_we}"
if [ ! -e ../CRISPR_Tools/ ]; then
    mkdir ../CRISPR_Tools/ -p
fi

if [ -e ${output_dir}/Flank.ndb ]; then
    echo "Already exist. skip."
    exit 1
fi

option=""
if [ -e ${output_dir} ]; then
    option="--redo_typing"
fi

if [ ${2} == "meta" ]; then
    echo "@@@@Metagenome mode@@@@"
    option="${option} --prodigal meta"
fi

#cctyper my.fasta my_output
command="cctyper ${1} ${output_dir} --threads ${THREADS} --db ${HOME}/database/CRISPRCasTyper ${option}"
echo ${command}
eval ${command}

exit 0






