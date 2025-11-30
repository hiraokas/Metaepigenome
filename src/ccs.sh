#!/bin/sh
#$ -m be
#$ -cwd

function usage() {
    cat <<'EOF'
===================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20170731
    History: 20200130
    History: 20221122 (add --hifi-kinetics)
    History: 20250924
    - A wrapper script of ccs command powered by PacBio.
Require:
    conda activate py38
    conda install pbccs -c bioconda
Usage:
    this.sh suubreads.bam output_dir _minPasses(def: 3) _minPredictedAccuracy(def: 0.99) 
    threads=60
Tips:
    ccs.sh ../data/CM1_5m/sequel_run/r54023_20191206_025047/6_F01/m54023_191210_002144.subreads.bam ../data/10_SQ_ccs 3 0.9
Ext:
    ./qsub_da.sh 36 ./ccs.sh ../data/00_original/CM1_5m/sequel_run/r54023_20191217_020140/1_A01/m54023_191217_021140.subreads.bam ../data/21_SQ_ccs/ 5 0.99
===================================================================================================================================
EOF
    return 0
}   

if [ $# -ne 4 ]; then
    echo "Error: Please set bam file"
    usage
    exit 1
fi

#-------------------------------------------
THREADS=60
ccs=${HOME}/miniconda3/envs/py38/bin/ccs

source ${HOME}/miniconda3/etc/profile.d/conda.sh
conda activate py38

output_dir=${2}
str_filename=${1##*/}                   #hogehoge.extendedFrags.fastq
str_filename_we=${str_filename%.*}      #hogehoge.extendedFrags
str_filename_wewe=${str_filename_we%.*} #hogehoge
_minPasses=${3}
_minPredictedAccuracy=${4}

output_file_prefix=${output_dir}/${str_filename_wewe}.${_minPasses}-${_minPredictedAccuracy}.ccs

if [ ! -e ${output_dir} ]; then
    mkdir ${output_dir} -p
fi

${ccs} ${1} ${output_file_prefix}.bam \
    --num-threads ${THREADS} \
    --min-passes  ${_minPasses} \
    --min-rq      ${_minPredictedAccuracy} \
    --report-file ${output_file_prefix}.report.txt \
    --hifi-kinetics

echo "output: ${output_file_prefix}.bam "
echo "All done."
exit 0
