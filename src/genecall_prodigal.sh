#!/bin/bash
#$ -m be
#$ -cwd
#$ -pe threads 1

function usage() {
    cat <<EOF
========================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: <2017
    History:  20220503 (add multi-split mode)
    History:  20221122 (accept fasta.gz)
    History:  20250531 (.fna ang .gff will not output as defalt)
    History:  20251225
    - This is a script for CDS prediction using Prodigal.
    - Input file is recommended to be splited by 5GB if exceeded.
    - To output fasta and gff files in addition to faa, add "all" option.
Required:
    seqkit, prodigal
Usage:
    genecall_prodigal input_file.fasta/q/fasta.gz meta/single/short [all]
TIPS:
     ./genecall_prodigal.sh ../data/Hiyori.0.fna single
========================================================================================================================================
EOF
    return 0
}

if [ $# -lt 2 ]; then
    echo "Error: Please set fasta file and mode"
    usage
    exit 1
fi

#init
start_time=`date +%s`
WORKNAME="Genecall (Prodigal)"
SEQKIT=${HOME}/local/bin/seqkit
PRODIGAL=${HOME}/workspace/software/prodigal.linux
PRODIGAL_SHROT=${HOME}/workspace/software/ripper/prodigal-short
OUT_DIR=../gene/genecall

INPUT_FILE=${1}
META_SINGLE=${2}
META_ALL=${3}
FILENAME=${INPUT_FILE##*/}
BASE_FILENAME=`echo ${FILENAME} | rev | cut -f2- -d "." | rev`
EXT=${FILENAME##*.}
FLAG=""
FLAG_fasta_gff=""

#(add "all" option for generate fasta/gff files)
# if [ $# -gt 3 ]; then
#     FLAG_fasta_gff=true
#     echo "fasta and gff files will be outputed."
# fi

#make dir
if [ ! -e ${OUT_DIR} ]; then
    mkdir ${OUT_DIR}/work -p
fi

#gene call
echo "${WORKNAME} start..."

#gz
if [ ${EXT} = "gz" ] ; then
    NEW_INPUT_FILE=${OUT_DIR}/${BASE_FILENAME}
    echo "Making tmp file: ${NEW_INPUT_FILE}"
    touch ${NEW_INPUT_FILE}
    gunzip  ${INPUT_FILE} -c >  ${NEW_INPUT_FILE}
    INPUT_FILE=${NEW_INPUT_FILE}
    EXT=${INPUT_FILE##*.}
    FLAG=${INPUT_FILE}
fi

#fastq->fasta
if [ ${EXT} = "fq" ] || [ ${EXT} = "fastq" ] ; then
    NEW_INPUT_FILE=${OUT_DIR}/${BASE_FILENAME}.fasta
    echo "Making tmp fasta file: ${NEW_INPUT_FILE}"
    touch ${NEW_INPUT_FILE}
    awk '(NR - 1) % 4 < 2' ${INPUT_FILE} | sed 's/@/>/' > ${NEW_INPUT_FILE}
    INPUT_FILE=${NEW_INPUT_FILE}
fi

#==================================================================================
# input: filepath
#==================================================================================
function my_prodigal() {
    InputFilePass=${1}
    echo "Input file: ${1}"

    FileName=${InputFilePass##*/}
    #BaseFileName=${FileName%.*}
    BaseFileName=`echo ${FileName} | rev | cut -f2- -d "." | rev`
    Output_prefix=${OUT_DIR}/${BaseFileName}

    Option="-f gff -o /dev/null "  # default: no gff output
    if [ "${META_ALL}" = "all" ]; then
        Option="-d ${Output_prefix}.cds.fna -f gff -o ${Output_prefix}.gff "
    fi

    if [ ${META_SINGLE} = "short" ]; then
    	BaseFileName=${BaseFileName}_short
    	#command="${PRODIGAL_SHROT} -i ${InputFilePass} -a ${Output_prefix}.pro.faa -d ${Output_prefix}.fna -f gff -o ${Output_prefix}.gff"
         command="${PRODIGAL_SHROT} -i ${InputFilePass} -a ${Output_prefix}.pro.faa ${Option}"
    else
    	#command="${PRODIGAL}       -i ${InputFilePass} -a ${Output_prefix}.pro.faa -p ${META_SINGLE} -q -d ${Output_prefix}.fna -f gff -o ${Output_prefix}.gff"
         command="${PRODIGAL}       -i ${InputFilePass} -a ${Output_prefix}.pro.faa -p ${META_SINGLE} -q ${Option}"
    fi

    if [ ! -e ${Output_prefix}.pro.faa ] || [ -e ${Output_prefix}.nowRunning ]; then
        touch ${Output_prefix}.nowRunning
        echo ${command}
        ${command}
        rm    ${Output_prefix}.nowRunning
    else
        echo "Output file is found. Skipped"
    fi
}
export -f my_prodigal 

#simple running
FileSize=`ls -s  ${INPUT_FILE} | cut -f1 -d " "`
echo "Filesize: ${FileSize}"
if [ ${FileSize} -lt 3000000 ]; then  #<3GB
    echo "simple running mode"
    my_prodigal ${INPUT_FILE}

#large-sige data
else
    echo "Sile size >3 GB. File will be splitted into SubFiles (<2 GB) and CDS prediction performed in each file."

    #sepalate
    if [ ! -e ${INPUT_FILE}.split/ ]; then
        ${SEQKIT} split2 -l 2G ${INPUT_FILE}
    fi

    #run
    PID=()  #list
    for f in ${INPUT_FILE}.split/*; do
        echo "Subfile: ${f}"
        #nohup bash -c my_prodigal ${f} &
        my_prodigal ${f} &
        PID+=("${!}")
    done

    #wait
    echo "Process list: ${PID[@]}"
    wait ${PID[@]}; echo "all done"


    #merge
    echo "merge"
    cat ${OUT_DIR}/${BASE_FILENAME}.part_*.pro.faa > ${OUT_DIR}/${BASE_FILENAME}.pro.faa
    cat ${OUT_DIR}/${BASE_FILENAME}.part_*.cds.fna > ${OUT_DIR}/${BASE_FILENAME}.cds.fna

    #erase
    echo "remove tmp files"
    rm -r ${INPUT_FILE}.split/
    mv ${OUT_DIR}/${BASE_FILENAME}.part_*.faa ${OUT_DIR}/work
    mv ${OUT_DIR}/${BASE_FILENAME}.part_*.fna ${OUT_DIR}/work
    mv ${OUT_DIR}/${BASE_FILENAME}.part_*.gff ${OUT_DIR}/work

fi

echo "${WORKNAME} done."

#derete template fasta file
if [ ! ${FLAG} = "" ]; then
    echo "Delete tmp file: ${FLAG}"
    rm ${FLAG}
fi
if  [ ${EXT} = "fq" ] || [ ${EXT} = "fastq" ] ; then
    echo "Delete tmp file: ${INPUT_FILE}"
    rm ${INPUT_FILE}
fi

#final
if [ $? -eq  0 ]; then
	echo "Success."
else
	echo "Failed."
fi
end_time=`date +%s`
PT=$((end_time - start_time))
H=`expr ${PT} / 3600`
PT=`expr ${PT} % 3600`
M=`expr ${PT} / 60`
S=`expr ${PT} % 60`
echo "Run Time: ${H}h ${M}m ${S}s"
echo "================================================================================="
exit 1
