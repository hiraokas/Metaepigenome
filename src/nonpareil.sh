#!/bin/sh
#$ -m be
#$ -cwd
#$ -pe threads 10

function usage() {
    cat <<'EOF'
==================================================================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: <20180826
    History:  20210131
    History:  20221128
    - This is a script for metagenome assenbly.
    - thread=10
Usage:
    $(basename ${0}) metagenome_shotgun.fasta/q [threads=10]
Tips:
    for f in ../data/16_fasta/JA_S00-01_1.fa/*.fa; do nonpareil.sh ${f}; done
==================================================================================================================================================================================
EOF
}

usage_exit() {
    usage 
    exit 1
}

#=====================================================
THREADS=10
nonpareil="${HOME}/software/nonpareil/nonpareil"
outputDir="../nonpareil"

if [ $# -le 0 ]; then
    usage_exit
fi

if [ $# -gt 1 ]; then
    THREADS=${2}
fi


echo "@@@nonpareil"
echo "Threads: ${THREADS}"

file_path=${1}

filename=`basename ${file_path}`
filename_prefix=${filename%.*} 
filename_ext=${filename##*.}
echo "File basename: ${filename}";

if [ ${filename_ext} = "fasta" ] || [ ${filename_ext} = "fa" ] || [ ${filename_ext} = "fna" ]; then
    format="fasta"
elif [ ${filename_ext} = "fastq" ] || [ ${filename_ext} = "fq" ]; then
    format="fastq"
else
    echo "Illigal file extension: ${filename_ext}"
    usage_exit
fi
echo "Mode: ${format}"

if [ ! -e ${outputDir} ]; then
    mkdir ${outputDir}
fi

if [ ! -e ${outputDir}/${filename_prefix}_kmer.npa ]; then
	${nonpareil} -s ${file_path}  -T kmer -b ${outputDir}/${filename_prefix}_kmer -t ${THREADS} -f ${format}
fi

echo "output: ${outputDir}/${filename_prefix}_kmer"
echo "@@@Done."
