#!/bin/bash
#$ -m be
#$ -cwd
#$ -pe threads 6

function usage() {
    cat <<'EOF'
==================================================================================================================================================================================
Description:
    created: 20210131
    History: 20210131
    History: 20230725 (checkv database v1.5)
    History: 20251226
    - Predict quality of viral genomes.
    - Script can be used for genomes, contigs, HiFi reads, etc.
Usage:
    conda activate py38
    ./checkv.sh genome.fasta [thread=6]
Install:
    - Install and download database
    conda create -n checkv -c conda-forge -c bioconda checkv
    conda activate checkv
    checkv download_database ${HOME}/database/checkv
==================================================================================================================================================================================
EOF
}

start_time=`date +%s`

#----------------------------------------------------------
threads=6
output_dir="../CheckV"
database="${HOME}/database/checkv/checkv-db-v1.5"
checkv="checkv"
#----------------------------------------------------------

if [ ! -e ${output_dir} ]; then
    mkdir ${output_dir}
fi

if [ $# -lt 1 ]; then
    echo "No imput file"
    usage
    exit 1
fi

if [ $# -gt 1 ]; then
    echo "Thread: ${2}"
    threads=${2}
fi

input_file=${1}

#make output filename
FILENAME=${input_file##*/}
BASE_FILENAME=${FILENAME%.*}
EXT=${FILENAME##*.}

output_maindir=${output_dir}/${FILENAME}

#seplate
#checkv contamination   ${input_file} ${output_maindir} -t ${threads} -d ${database}
#checkv completeness    ${input_file} ${output_maindir} -t ${threads} -d ${database}
#checkv repeats         ${input_file} ${output_maindir} -d ${database}
#checkv quality_summary ${input_file} ${output_maindir} -d ${database}

#----------------------------------------------------------
source ${HOME}/miniconda3/etc/profile.d/conda.sh
conda activate checkv
#----------------------------------------------------------

#all run
${checkv} end_to_end ${input_file} ${output_maindir} -d ${database} -t ${threads}

#remove tmp file
rm -r ${output_maindir}/tmp

end_time=`date +%s`
PT=$((end_time - start_time))
H=` expr ${PT} / 3600`
PT=`expr ${PT} % 3600`
M=` expr ${PT} / 60`
S=` expr ${PT} % 60`
echo "Run time: ${H}h ${M}m ${S}s"

echo "done"
exit 0
