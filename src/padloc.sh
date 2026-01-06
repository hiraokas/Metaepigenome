#!/bin/bash
#$ -m be
#$ -cwd
#$ -pe threads 1

function usage() {
    cat <<'EOF'
========================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20230403
    History: 20230624 (add gene mode)
    History: 20251225
    - This is a wrapper of Padloc for defense system prediction from genome.
Required:
    Conda environment (padloc)
Usage:
    this.sh genome genome.fasta           [threads=6]
    this.sh gene   gene.faa     gene.gff  [threads=6]
Install:
    conda create -n padloc -c conda-forge -c bioconda -c padlocbio padloc=2.0.0
    conda activate padloc
    padloc --db-update

    # conda install -c conda-forge r-tidyverse yaml getopt 
    # R
    # install.packages("tidyverse", repos = "http://cran.us.r-project.org")
    # install.packages("yaml",      repos = "http://cran.us.r-project.org")
    # install.packages("getopt",    repos = "http://cran.us.r-project.org")

    #DDBJ
    #https://sc.ddbj.nig.ac.jp/software/spack/install_spack/
#     cd ~/work/software
#     git clone -c feature.manyFiles=true https://github.com/spack/spack.git
#     export SPACK_ROOT=/home/hiraoka-s/workspace/software/spack
#     source $SPACK_ROOT/share/spack/setup-env.sh
#     spack compiler find
#     spack install -j 4 gcc@8.5.0
#     spack load gcc@8.5.0
#     nano $HOME/.spack/linux/compilers.yaml
# - compiler:
#     spec: gcc@8.5.0
#     paths:
#       cc: /lustre7/home/lustre4/youraccount/spack/opt/spack/linux-centos7-x86_64_v3/gcc-4.8.5/gcc-8.5.0-a4dcd4j7uq23aax4n6ri6amzt7hp4lxc/bin/gcc
#       cxx: /lustre7/home/lustre4/youraccount/spack/opt/spack/linux-centos7-x86_64_v3/gcc-4.8.5/gcc-8.5.0-a4dcd4j7uq23aax4n6ri6amzt7hp4lxc/bin/g++
#       f77: /lustre7/home/lustre4/youraccount/spack/opt/spack/linux-centos7-x86_64_v3/gcc-4.8.5/gcc-8.5.0-a4dcd4j7uq23aax4n6ri6amzt7hp4lxc/bin/gfortran
#       fc: /lustre7/home/lustre4/youraccount/spack/opt/spack/linux-centos7-x86_64_v3/gcc-4.8.5/gcc-8.5.0-a4dcd4j7uq23aax4n6ri6amzt7hp4lxc/bin/gfortran
#     flags: {}
#     operating_system: centos7
#     target: x86_64
#     modules: []
#     environment: {}
#     extra_rpaths: []

========================================================================================================================================
EOF
    return 0
}   

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

threads=6
mode=${1}

source ${HOME}/miniconda3/etc/profile.d/conda.sh
conda activate padloc

# get DB version
DBversion=`padloc --db-version | cut -f2 -d " "`
output_dir=../padloc/work_DB${DBversion}

FILENAME=${2##*/}
BASE_FILENAME=${FILENAME%.*}

echo "==========================================================="
echo "mode:          ${mode}"
echo "Input:         ${2}    ${3}"
echo "Output dir:    ${output_dir}"
echo "Output prefix: ${FILENAME}"
echo "==========================================================="
#echo "Threads        ${threads}"

#module load r/3.5.2  #for DDBJ server
export R_LIBS_USER=${HOME}/miniconda3/envs/padloc/lib/R/library

if [ ! -e ${output_dir} ]; then
    mkdir ${output_dir} -p
fi 

if [ -e ${output_dir}/${FILENAME}.check ]; then
    echo "Likely already done. Exit. ${1}"
    exit 0
fi

if [ ${mode} == "genome" ]; then   
    if   [ $# -gt 2 ]; then
        echo "threads: ${3}"
        threads=${3}
    fi

    padloc --fna ${2}            --outdir ${output_dir} --cpu ${threads} --force
elif   [ ${mode} == "gene" ]; then  
    if   [ $# -gt 3 ]; then
        echo "threads: ${4}"
        threads=${4}
    fi

    padloc --faa ${2} --gff ${3} --outdir ${output_dir} --cpu ${threads} --force --fix-prodigal
else
    echo "Illigal mode: ${mode}. Exit."
    exit
fi

#success
if [ -e ${output_dir}/${FILENAME}.domtblout ]; then
    touch ${output_dir}/${FILENAME}.check
fi

#remove tmp files
#rm ${output_dir}/${FILENAME}_prodigal.faa
#rm ${output_dir}/${FILENAME}_prodigal.gff
#rm ${output_dir}/${FILENAME}.domtblout

#move  output files
mv ${output_dir}/${FILENAME}_padloc.csv ${output_dir}/../
mv ${output_dir}/${FILENAME}_padloc.gff ${output_dir}/../

echo "All done."
