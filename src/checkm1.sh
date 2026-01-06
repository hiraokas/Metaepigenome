#!/bin/sh

function usage() {
    cat <<"EOF"
========================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20171028
    History: 20200109
    History: 20251223
    - A wrapper of CheckM1 for quality check of genomes.
    - CheckM maybe takes a lot of memory (>100G in 20 threads with >400 bins)
Usage:
    conda activate checkm1
    ./checkm1.sh bins_dir [threads=20]
    ./checkm1.sh install   (print help page)
Tips:
    ./qsub_mem_da.sh 40 ./checkm.sh ../binning/vamb_DSSMv0.2_concatenate/vamb_DSSMv0.2_concatenate/ 20
========================================================================================================================================
EOF
	exit 1
}

function usage_install() {
    cat <<"EOF"
========================================================================================================================================
-------------------------------
For installing CheckM
-------------------------------
    - See: https://github.com/Ecogenomics/CheckM/wiki/Installation#how-to-install-checkm
    conda create -n checkm1 python=3.9
    conda activate checkm1
    # #conda install numpy matplotlib pysam -c bioconda
    # #conda install hmmer prodigal 
    # conda install pplacer
    # python -m pip install checkm-genome
    conda install -c bioconda checkm-genome

    - Before use this script, provided database should be placed under dir that prisetted by checkm.
    - https://data.ace.uq.edu.au/public/CheckM_databases/
    checkm data setRoot ${HOME}/database/checkm/  
========================================================================================================================================
EOF
    exit 1
}

usage_exit() {
    usage
    exit 1
}

if [ $# -le 0 ]; then
    usage_exit
fi

if [ ${1} == "install" ]; then
    usage_install
    exit 1
fi

start_time=`date +%s`

#----------------------------------------------------------
threads=20
output_dir="../CheckM1"
source ${HOME}/miniconda3/etc/profile.d/conda.sh
conda activate checkm1
#----------------------------------------------------------

# Log
echo "===================================================================="
echo $(which hmmsearch)
echo $(which prodigal)
echo $(which checkm)
echo "===================================================================="

if [ ! -e ${output_dir} ]; then
    mkdir ${output_dir}
fi
input_dir=${1}
echo "Input dir: ${input_dir}"

if   [ $# -gt 1 ] ; then
    threads=${2}
    echo "Threads: ${2}"
fi

# If the last character of the input filename is "/", delete it.
last_char=`echo ${input_dir}| rev | cut -c1 | rev`
if [ ${last_char} = "/" ]; then
    input_dir=`echo ${input_dir} | rev | cut -c2- | rev`
fi

# get dir name for output file prefix
output_prefix=${input_dir##*/}

# output files
temp_output_log="${output_dir}/${output_prefix}_log.tsv"
temp_output_result="${output_dir}/${output_prefix}_result.tsv"
output_maindir="    ${output_dir}/${output_prefix}"
output_workdir="    ${output_maindir}/workdir"
output_log="        ${output_maindir}/log.tsv"
output_result="     ${output_maindir}/checkm1_${output_prefix}.tsv"

if [ -e ${output_maindir} ]; then
    rm ${output_maindir} -r
    sleep 1
fi
touch ${temp_output_log}

#check query file format
QUERY_FILE_ONE=`ls ${input_dir}|head -3 | tail -1 `  #contig, depth.tsv, [ XX.1.fa ], xx.2.fa, ...
EXT=${QUERY_FILE_ONE##*.}  # first query file format
echo ${EXT}


echo "Checkm running..."
command="checkm lineage_wf -t ${threads} -x ${EXT} ${input_dir} ${output_maindir}"
echo ${command}
echo "# ${command}" >> ${temp_output_log}
${command}          >> ${temp_output_result}

#move files after the main directory is created by CheckM and finished the process
mv ${temp_output_log}    ${output_log}
mv ${temp_output_result} ${output_result}

#remove some tmp dir
rm -r ${output_maindir}/bins
rm -r ${output_maindir}/storage
rm -r ${output_maindir}/lineage.ms

echo "output: ${output_log}"
./runtime.sh "${start_time}"
echo "done"

exit 0
