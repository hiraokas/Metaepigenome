#!/bin/sh
#$ -m be
#$ -cwd

function usage() {
    cat <<'EOF'
========================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20250707
    History: 20250929
    - thread = 6
    - This is a wrapper of CRISPRCasFinder to predict CRISPR system.
    - https://github.com/dcouvin/CRISPRCasFinder
Usage:
    this target.fasta
Install:
    cd ~/workspace/software
    wget https://github.com/dcouvin/CRISPRCasFinder/archive/refs/tags/release-4.3.2.tar.gz
    tar -xvf release-4.3.2.tar.gz
    cd CRISPRCasFinder-release-4.3.2/

    conda env create -f ccf.environment.yml -n crisprcasfinder
    conda activate crisprcasfinder
    conda install -c bioconda macsyfinder=2.1.2
    macsydata install -u CASFinder==3.1.0
    # bash installer_CENTOS.sh

    perl CRISPRCasFinder.pl -in install_test/sequence.fasta -cas -keep
========================================================================================================================================
EOF
    return 0
}   

THREADS=6
if [ $# -gt 1 ]; then
    THREADS=${2}
fi
echo "Threads: ${THREADS}"


CRISPRCasFinder="${HOME}/software/CRISPRCasFinder-release-4.3.2/CRISPRCasFinder.pl"
# perl ${HOME}/software/CRISPRCasFinder-release-4.3.2/CRISPRCasFinder.pl -h
# perl ${HOME}/software/CRISPRCasFinder-release-4.3.2/CRISPRCasFinder.pl -in ${HOME}/software/CRISPRCasFinder-release-4.3.2/install_test/sequence.fasta   -cpuM 6  -soFile ${HOME}/workspace/software/CRISPRCasFinder-release-4.3.2/sel392v2.so --outdir test
# perl ${HOME}/software/CRISPRCasFinder-release-4.3.2/CRISPRCasFinder.pl -in ${HOME}/software/CRISPRCasFinder-release-4.3.2/install_test/sequence.fasta -cas -log -keep  -cpuM 6  -soFile ${HOME}/workspace/software/CRISPRCasFinder-release-4.3.2/sel392v2.so --outdir test

if [ $# -lt 1 ]; then
    echo "Error: Please set two options; 'database path' and 'query file'"
    usage
    exit 1
fi

source ${HOME}/miniconda3/etc/profile.d/conda.sh
conda activate crisprcasfinder

str_filename=${1##*/}
str_filename_we=${str_filename%.*}
str_dirname=$(dirname ${1})
echo "Input file: ${str_filename_we}"

output_dir="../CRISPR_Tools/CRISPRCasFinder_${str_filename_we}"

perl ${CRISPRCasFinder} -in ${1} --outdir ${output_dir} -cas -log  -cpuM ${THREADS} -keepAll  -soFile ${HOME}/workspace/software/CRISPRCasFinder-release-4.3.2/sel392v2.so


exit 0



