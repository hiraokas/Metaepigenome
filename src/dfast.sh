#!/bin/sh
#$ -m be
#$ -cwd
#$ -pe threads 10

function usage() {
    cat <<EOF
==================================================================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: <2022
    History:  20220709 (change memo to sh script)
    History:  20230720 (using conda version)
    History:  20250111 (return to stand-alone version)
    History:  20250220
    - This script is for dfast that is a tool of genome annotation including functional gene annotation.
    - Use Biopython
    - thread = 6
Usage:
    this.sh genome.fa
Output:
    cds.fna
    genome.fna
    protein.faa
    rna.fna
    etc.
INSTALL:
    # conda (not recommend)
    conda install dfast=1.3.4 -c bioconda

    # mannual install
    wget https://github.com/nigyta/dfast_core/archive/refs/tags/1.3.4.tar.gz
    tar xvfz 1.3.4.tar.gz
    cd dfast_core-1.3.4
    ln -s dfast ~/local/bin/
    ln -s scripts/dfast_file_downloader.py ~/local/bin/
    conda activate py38
    conda install biopython -c bioconda 
For ES system
    cp     /usr/lib64/libidn.so.11.6.18 ~/local/lib/ # for blastp at qlogin server, ES system
    ln -s ~/local/lib/libidn.so.11.6.18 ~/local/lib/libidn.so.11 # for blastp at qlogin server, ES system
    qlogin -q cpu_I -l elapstim_req=8:00:00 -X  
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:~/local/lib/
Making databases:
    ~/workspace/software/dfast_core-1.3.4/scripts/dfast_file_downloader.py --protein dfast
==================================================================================================================================================================================
EOF
}

usage_exit() {
    usage
    exit 1
}

if [ $# -lt 1 ]; then
    echo "Insufficient parameters"
    usage
    exit 1
fi

#=============================================
#set pass
#=============================================
source ${HOME}/miniconda3/etc/profile.d/conda.sh
conda activate py38

#dfast_dir="${HOME}/workspace/software/dfast_core"
dfast_dir="${HOME}/workspace/software/dfast_core-1.3.4"
#dfast_dir="${HOME}/workspace/software/dfast_core-1.2.12_virus"

dfast="${dfast_dir}/dfast"
outdir=" ../dfast"

threads=6

#=============================================
#run (prokaryote version)
#=============================================
InputFile=${1}
str_filename=${InputFile##*/}
str_filename_we=${str_filename%.*}

${dfast} -g ${InputFile} --use_prodigal \
    --organism "Escherichia coli" \
    --strain "str. xxx" \
    --out ${outdir}/${str_filename_we} \
    --no_hmm --no_cdd \
    --cpu ${threads} \
    --force

    #--locus_tag_prefix ECXXX \
    #--database ${database}/DFAST-default \
    #--minimum_length 200 \

echo "Output: ${outdir}/${str_filename_we}"
exit 0









#=============================================
#run (Virus version)
#=============================================
for f in ../ViralGenome/*.fa; do

    str_filename=${f##*/}
    str_filename_we=${str_filename%.*}

    dfast -g ${f} --use_prodigal \
        --organism "Escherichia coli" \
        --strain "str. xxx" \
        --out ${outdir}/${str_filename_we} \
        --no_hmm --no_cdd \
        --cpu 40 \
        --minimum_length 100 \
        --force
done




