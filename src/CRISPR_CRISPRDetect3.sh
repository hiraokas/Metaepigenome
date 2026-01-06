#!/bin/bash
#$ -m be
#$ -cwd

function usage() {
    cat <<'EOF'
==================================================================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20210803
    History: 20220928 (Add threads option)
    History: 20251223
    - This is a wrapper of CRISPRDetect3 to predict CRISPR array.
    - https://github.com/ambarishbiswas/CRISPRDetect_3.0
Output:
    - ../CRISPR/CRISPRDetect3/XXX_genomic.fna.XXX
Install:
    #wget  http://www.tbi.univie.ac.at/~ronny/RNA/packages/source/ViennaRNA-2.1.3.tar.gz
    #tar -xvf ViennaRNA-2.1.3.tar.gz
    # cd ViennaRNA-2.1.3/
    #./configure --prefix=${HOME}/local/bin
    #make -j 10
    #make install

    #conda activate py38
    #conda install -c bioconda emboss clustalw viennarna cd-hit
    ${HOME}/software/CRISPRDetect_3.0/CRISPRDetect3
Usage:
    this target.fasta [threads=6]
==================================================================================================================================================================================
EOF
    return 0
}   

CRISPRDetect3="${HOME}/software/CRISPRDetect_3.0/CRISPRDetect3"
output_dir="../CRISPR_Tools/CRISPRDetect3/"

if [ $# -lt 1 ]; then
    echo "Error: Please set two options; [database path] and [query file]"
    usage
    exit 1
fi

THREADS=6
if [ $# -gt 1 ]; then
    THREADS=${2}
fi
echo "Threads: ${THREADS}"

str_filename=${1##*/}
str_filename_we=${str_filename%.*}
str_dirname=$(dirname ${1})

if [ ! -e ${output_dir} ]; then
    mkdir ${output_dir} -p
fi

output_filepath=${output_dir}/${str_filename_we}  #GCA_000756735.1_genomic.fna.spacers.fa

real_filepath=`readlink ${1} -f`
echo "Input file: ${real_filepath}"

if [ ! -e ${output_filepath}.spacers.fa ]; then
    source ${HOME}/miniconda3/etc/profile.d/conda.sh
    conda activate py38

    # in case of GZ
    inputFilePath=${1}
    EXTNAME=${inputFilePath##*.}
    if [ ${EXTNAME} == "gz" ]; then
        echo "Melt gz file: ${inputFilePath}"
        gunzip ${inputFilePath} -k
        inputFilePath=`echo "${inputFilePath}" | sed -e "s/.gz$//g"`
    fi

    ${CRISPRDetect3} -f ${inputFilePath} -o ${output_filepath} -check_direction 0 -array_quality_score_cutoff 3 -T ${THREADS} 
    echo "File output: ${output_filepath}"
    mv ${output_filepath} ${output_filepath}.out

    if [ ${EXTNAME} == "gz" ]; then
        echo "Delete melted file: ${inputFilePath}"
        rm ${inputFilePath}
    fi
else
    echo "File already exist: ${output_filepath}.spacers.fa"
    exit 1
fi

echo "All done."
