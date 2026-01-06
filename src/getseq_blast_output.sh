#!/bin/sh
#$ -m be
#$ -cwd
#$ -pe threads 1

function usage() {
    cat <<EOF
========================================================================================================================================
Description:
    $(basename ${0}) is a tool for extracting specific sequences using blast output files (format=6)
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20190401
    History: 20190409
    History: 20210924
    History: 20220922 (accept for hmmer output)
    History: 20230317 (change output dir)
    History: 20251226
    - Script to get hit sequences by blast-like search tools (blast, DIAMOND, hmmer, etc.)
Output dir:
    ../CandidateSeq_blast or ../CandidateSeq_domtblout
Usage:
    $(basename ${0}) sequence.faa(.gz) output.blast [threads=4]
TIPS:
    ./getseq_blast_output.sh ../genecall/megahit_all_20181117.faa  ../blast/blast_megahit_all_20181117.tsv
========================================================================================================================================
EOF
}

usage_exit() {
    usage
    exit 1
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

input_seq_file=${1}
blast_output=${2}
echo ${blast_output}
threads=4

if [ $# -gt 2 ]; then
    thread=${3}
fi

SeqFilename=${input_seq_file##*/}
SeqFilenameBase=`echo ${SeqFilename} | sed -e "s/.gz//g" -e "s/.faa//g" `
SeqFileExt=`     echo ${SeqFilename} | sed -e "s/.gz//g" | rev | cut -f1 -d "." | rev`

BlastFilename=${blast_output##*/}
BlastFilenameBase=${BlastFilename%.*}
BlastFileExt=${BlastFilename##*.}

OutputDir="../CandidateSeq_${BlastFileExt}"  #CandidateSeq_blast / CandidateSeq_domtblout
mkdir ${OutputDir} -p

output_genelist="${OutputDir}/${BlastFilenameBase}_${SeqFilenameBase}.tsv"
output_geneseq=" ${OutputDir}/${BlastFilenameBase}_${SeqFilenameBase}.${SeqFileExt}"

echo "==================================="
echo "threads: ${threads}"
echo "output_genelist: ${output_genelist}"
echo "output_geneseq:  ${output_geneseq}"
echo "==================================="

touch ${output_genelist}
echo "get blasted sequence IDs"
cat ${blast_output} | grep -v "^#" | sed -e 's/  */\t/g' | cut -f1  > "${output_genelist}"
echo "Output: ${output_genelist}"

echo "extract all blasted sequences"
seqkit grep -f ${output_genelist} ${input_seq_file} -o ${output_geneseq} -j ${threads} #  --quiet
echo "Output: ${output_geneseq}"
echo ""

rm ${output_genelist}

#echo "filtered complete sequence"
#grep "partial=00" ${output_geneseq} | cut -f1 -d " " | cut -c2- > ${output_genelist2}

#echo "extract complete blasted sequences"
#seqkit grep -f ${output_genelist2} ${output_geneseq} -o ${output_geneseq2}
#echo "output: ${output_geneseq2}"

echo "Done."
