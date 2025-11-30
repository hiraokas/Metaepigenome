#!/bin/bash

function usage() {
    cat <<EOF
========================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20220104
    History: 20230729
    - $(basename ${0}) is a script for MAG dereplication.
    - dRep for prokaryotic MAG
        - considering CheckM1 quality and contamination
        - This process will takes huge memory size (>150 GB with 20 MAGs, and ~250 GB with 1800 MAGs).
        - This may depends on the number of used threads. This is owned by pplacer)
        - !!!!!!!!!!!!!MAX THREADS SHOULD BE <6 UNDER THE DA SYSTEM !!!!!!!!!!!!! (20220622)
    - galah for prokaryotic and virus MAG
        - with/without consideration of the MAG quality 
    
    - Thresholds: conpleteness  = 0% (default=75%)
                  contamination = 0% (default=25%)
                  length = 50k       (default=50k)
Usage:
    $(basename ${0})  Bins_dir_path mode [threads=6]
mode:
    dRep_species
        ANI = 0.95 (speciese)
        - using dRep with checkm1
    dRep_strict
        ANI = 0.99 (strict)
        - using dRep with checkm1
    galah_virus      
        ANI    = 0.95
        length = 1kb  (small contigs are accepted)
        - using galah
Exp:
    ./drep.sh ../binning/DSSMv0.1_test/  species
Install:
    cd ~/workspace/software/
    conda create -n dRep python=3.8
    conda activate dRep
    conda install -c bioconda drep  fastANI  numpy==1.23 -y

    git clone https://github.com/infphilo/centrifuge
    cd centrifuge
    make -j 8
    make install prefix=~/local

    wget https://ani.jgi-psf.org/download_files/ANIcalculator_v1.tgz 
    tar -zxvf ANIcalculator_v1.tgz 
    cd ANIcalculator_v1 
    cp ANIcalculator ~/local/bin/

    # conda install -c bioconda checkm-genome   -y
    checkm data setRoot ${HOME}/database/checkm/ 
    # mash mummer fastANI prodigal pplacer  nsimscan  ANIcalculator

    #downgrade numpy
    conda install numpy==1.23 -y

    dRep check_dependencies

    ----------------------------------------------
    conda create -n galah -y
    conda activate galah
    conda install -c bioconda galah -y
    conda install -c bioconda dashing=0.4  #downgrade version
========================================================================================================================================
EOF
}

usage_exit() {
    usage
    exit 1
}

if [ $# -le 1 ]; then
    usage_exit
fi

input_dir=${1}
threads=6
ANI=0.95
LENGTH=50000
outputDir=../dereplicate


mode=${2}

if [ $# -gt 2 ]; then
    threads=${3}
fi
echo "Threads: ${threads}"

if [ ! -e ${outputDir} ]; then
    mkdir ${outputDir}
fi

prefix=`basename ${input_dir}`
output_dir="${outputDir}/${prefix}_${mode}"
output_tsv="${outputDir}/${prefix}_${mode}.tsv"

if   [ ${mode} = "dRep_species" ]; then
    ANI=0.95
elif [ ${mode} = "dRep_strict" ]; then
    ANI=0.99
elif [ ${mode} = "galah_virus" ]; then
    ANI=0.95
    LENGTH=1000
fi



if [ ! -e ${output_dir} ]; then
    mkdir ${output_dir}
fi

echo "================================================================================================="
echo "Files:"
ls ${input_dir}*.fa
echo "---------------------------------------------------------------------"
echo "OutputDir: ${output_dir}"
echo "Mode: ${mode}"
echo "================================================================================================="

if [ ${mode} = "dRep_species" ] ||  [ ${mode} = "dRep_strict" ] ; then
    source ${HOME}/miniconda3/etc/profile.d/conda.sh
    conda activate dRep
    
    dRep dereplicate ${output_dir} -g ${input_dir}/*.fa -p ${threads} --S_algorithm ANImf -comp 0 -con 0   --primary_chunksize 500 -sa ${ANI} -l ${LENGTH}
    #--multiround_primary_clustering
    # -l 100000

    #clean up
    rm -r ${output_dir}/data
    rm -r ${output_dir}/data_tables


elif  [ ${mode} = "galah_virus" ]; then
    source ${HOME}/miniconda3/etc/profile.d/conda.sh
    conda activate galah 

    galah cluster --genome-fasta-directory ${input_dir}/ --genome-fasta-extension fa --output-cluster-definition ${output_tsv} \
        --output-representative-fasta-directory-copy ${output_dir} --threads ${threads} --ani 95

else
    echo "Unidentified mode: ${mode}"
    echo "Exit"
    exit 0
fi


#dRep compare output_directory -g path/to/genomes/*.fasta


echo "All done"
