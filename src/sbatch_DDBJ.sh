#!/bin/bash

function usage() {
    cat <<EOF
========================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20220204
    History: 20250301 (Change for Slurm. System was replacd in 2025.)
    History: 20251226
    - Que list:  epyc  rome  short  medium  #gpu 
Usage:
    $(basename ${0})  Que  Threads  Memory(per_thread)  Hour  Commands...
Exp:
    ./qsub.sh medium 6 8 48 XX.sh XX XX ..
========================================================================================================================================
EOF
}

usage_exit() {
    usage
    exit 1
}

if [ $# -le 3 ];   then usage_exit; fi
if [ ! -e QSUB/ ]; then mkdir QSUB; fi

set -e
que=${1}
thread=${2}
memory=${3}
hour=${4}
command=${@:5:($#-1)}

timestamp=`date +%Y%m%d-%H-%M-%S`
a=`echo ${0##*/} | cut -f1 -d "."`;
b=`echo ${5##*/} | cut -f1 -d "."`;
RequestID=${b}.${a}.${1##*/}.${timestamp}.XXXXXX  #modification_pacbio.sbatch_DDBJ.rome.20250324-13-24-14.f5Bm1j
tmpfile=$(mktemp "QSUB/${RequestID}")
scriptfile=`basename ${tmpfile}`
new_command=${command}
current_dir=`pwd`

option=""
if [ ${que} == "gpu" ]; then
    option="#SBATCH --gres=gpu:4"
fi

##$ -M hiraokas@jamstec.go.jp
#SBATCH -J sh_${RequestID}
##SBATCH --chdir ${current_dir}
#cd ${current_dir}; echo "${current_dir}"
#pwd
#ls
#----------------<script start>----------------
cat <<EOF > ${tmpfile}
#!/bin/bash
#SBATCH --time ${hour}:00:00
#SBATCH --nodes 1-1 
#SBATCH --ntasks ${thread}
#SBATCH --mem-per-cpu ${memory}g
#SBATCH --partition ${que}
#SBATCH --output ${current_dir}/QSUB/${scriptfile}.out
#SBATCH --error  ${current_dir}/QSUB/${scriptfile}.err
${option}

# command=========================================================
bash -c "${new_command}"
# ================================================================
EOF
#----------------<script end>----------------

cat ${tmpfile}
chmod +x ${tmpfile}
b=`basename ${tmpfile}`

command="sbatch ${tmpfile} "
echo ${command}; eval ${command}

exit 0
