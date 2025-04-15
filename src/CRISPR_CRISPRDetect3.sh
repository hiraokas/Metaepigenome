#!/bin/sh
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
    History: 20221018
    - thread = 6
Install:
    conda activate py38
    conda install -c bioconda emboss clustalw viennarna cd-hit
    ${HOME}/software/CRISPRDetect_3.0-master/CRISPRDetect3
Usage:
    this target.fasta [threads=6]
==================================================================================================================================================================================
EOF
    return 0
}   


THREADS=6

CRISPRDetect3="${HOME}/software/CRISPRDetect_3.0-master/CRISPRDetect3"
output_dir="../CRISPR/CRISPRDetect3/"

if [ $# -lt 1 ]; then
    echo "Error: Please set two options; [database path] and [query file]"
    usage
    exit 1
fi

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

output_filepath=${output_dir}/${str_filename_we}

#touch ${tmp_filename}
real_filepath=`readlink ${1} -f`
echo "Input file: ${real_filepath}"

if [ -e ${output_filepath} ] & [ ! -s ${output_filepath} ]; then
    source ${HOME}/miniconda3/etc/profile.d/conda.sh
    conda activate py38
    
    ${CRISPRDetect3} -f ${1} -o ${output_filepath} -check_direction 0 -array_quality_score_cutoff 3 -T ${THREADS} 
    echo "File output: ${output_filepath}"
    mv ${output_filepath} ${output_filepath}.out
else
    echo "File already exist: ${output_filepath}"
    exit 1
fi


echo "All done."
