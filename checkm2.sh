#!/bin/sh

function usage() {
    cat <<"EOF"
========================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Fork   : 20220828
    History: 20250108
    - For quality check of genomes using CheckM2
Note:
	threads=20
Usage:
    conda activate checkm2
    ./checkm2.sh bins_dir [threads=20]
    ./checkm2.sh test     [threads=20]   (for test)
    ./checkm2.sh install                 (for install setting)
Tips:
    ./qsub_mem_da.sh 40 ./checkm2.sh ../binning/vamb_DSSMv0.2_concatenate/vamb_DSSMv0.2_concatenate/ 20
    ./qsub_medium.sh 20 ./checkm2.sh ../my_binning/P-MAGs_v0.1/ 20
    ./qsub_medium.sh 20 ./checkm2.sh test 20    
========================================================================================================================================
EOF
	exit 1
}

function usage_H() {
    cat <<"EOF"
========================================================================================================================================
-------------------------------
For installing CheckM
-------------------------------
    - Before use this script, provided database should be placed under dir that prisetted by checkm.
    - https://data.ace.uq.edu.au/public/CheckM_databases/
    checkm data setRoot ${HOME}/database/checkm/

    #CheckM2
    #git clone --recursive https://github.com/chklovski/checkm2.git
    wget https://github.com/chklovski/CheckM2/archive/refs/tags/1.0.2.tar.gz  #should download latest version
    tar -xvf 1.0.2.tar.gz
    cd CheckM2-1.0.2/
    
    conda env create -n checkm2 -f checkm2.yml  #may take a long time...?
    conda activate checkm2
    conda install checkm2 -c bioconda
    #if needed------------------------
    conda uninstall tensorflow  #remove 
    python -m pip install tensorflow
    #conda install tensorflow  # not good version 
    #conda install tensorflow-gpu
    ##conda install tensorflow-estimator
    #--------------------------------


    # for ES system : 
    conda create -n checkm2  python==3.8
    conda activate checkm2
    #conda install -c bioconda  scikit-learn==0.23.2 h5py==2.10.0 numpy==1.16.4 diamond==2.0.4 tensorflow>=2.3.0 lightgbm==3.2.1 pandas scipy prodigal==2.6.3 setuptools requests packaging tqdm
    conda install -c bioconda  numpy==1.19.2 diamond  scikit-learn==0.23.2 h5py==2.10.0 lightgbm==3.2.1 pandas==1.4.0 scipy=1.8.0 prodigal setuptools requests packaging tqdm
    python -m pip install tensorflow==2.5 # numpy==1.19.2
    python setup.py install  # for checkm2 

    #make specific library and path
    ln -s ~/local/lib/libcuda.so.1 /opt/share/CUDA/11.6.2/targets/x86_64-linux/lib/stubs/libcuda.so
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${HOME}/local/lib/


    checkm2 database --download --path ${HOME}/database/checkm2/  #this will takes <30 min
    #checkm2 database --current ${HOME}/database/checkm2/  #not work...

-------------------------------
Scipt modification
-------------------------------
    # modify script to add encoding type in L104 etc. (file open) (2 places (?))
    nano ~/miniconda3/envs/checkm2/lib/python3.8/site-packages/CheckM2-1.0.2-py3.8.egg/checkm2/sequenceClasses.py
    , encoding="utf-8"

    #------------------------------------------------
        if outputFile.endswith('.gz'):
            fout = gzip.open(outputFile, 'wb', encoding="utf-8")
        else:
            fout = open(outputFile, 'w', encoding="utf-8")
    #------------------------------------------------

-------------------------------
Test Run
-------------------------------
    #ES
    module purge
    module load CUDA/11.6.2
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${HOME}/local/lib/
    checkm2 testrun --threads 10 --database_path ${HOME}/database/checkm2/CheckM2_database/uniref100.KO.1.dmnd
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
    usage
    exit 1
fi

start_time=`date +%s`
threads=20

output_dir="../CheckM2"
database_path="${HOME}/database/checkm2/CheckM2_database/uniref100.KO.1.dmnd"

source ${HOME}/miniconda3/etc/profile.d/conda.sh
conda activate checkm2

# for DDBJ
#module load tensorflow2-py36-cuda10.1-gcc/2.0.0

# for ES system
module purge
module load CUDA/11.6.2
#module load NVIDIAHPCSDK/22.3/nvhpc
#ln -s ~/local/lib/libcuda.so.1 /opt/share/CUDA/11.6.2/targets/x86_64-linux/lib/stubs/libcuda.so
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${HOME}/local/lib/


echo "=================================="
echo $(which hmmsearch)
echo "=================================="

if [ ! -e ${output_dir} ]; then
    mkdir ${output_dir}
fi

if [ ${1} == "test" ]; then
    echo "Test mode."
    rm -r ${output_dir}/test
    checkm2 testrun --threads 10   --lowmem --output-directory ${output_dir}/$test --database_path ${database_path}
    exit 0
fi

input_dir=${1}

if   [ $# -gt 1 ] ; then
    threads=${2}
    echo "Threads: ${2}"
fi

# make output filename
last_char=`    echo ${input_dir}|rev|cut -c1 |rev`
if [ ${last_char} = "/" ]; then
    input_dir=`echo ${input_dir}|rev|cut -c2-|rev`
fi
echo "Input dir: ${input_dir}"

# set filenames
str_filename=${input_dir##*/}
output_maindir="${output_dir}/${str_filename}"
output_result=" ${output_maindir}/quality_report.tsv"
final_result="  ${output_dir}/checkm2_${str_filename}.tsv"

if [ -e ${output_maindir} ]; then
    rm ${output_maindir} -r
    sleep 1
fi

# check query file format
QUERY_FILE_ONE=`ls ${input_dir}|head -3 | tail -1 `  #contig, depth.tsv, [ XX.1.fa ], xx.2.fa, ...
EXT=${QUERY_FILE_ONE##*.}  # first query file format
echo ${EXT}

echo "CheckM2 running..."

# For one genome
#checkm2 predict --threads ${threads}  --input input_genome.fa --output-directory out_dir

# For multiple genome
#checkm2 predict --threads ${threads}  --input MAG*.fa --output-directory out_dir

# For directory
checkm2 predict -x ${EXT} --threads ${threads}  --input ${input_dir} --output-directory ${output_maindir}   --lowmem  --database_path ${database_path}

# move output files after the creation of main directory by CheckM2 and finished the process
mv ${output_result} ${final_result}

# cleanup
rm -r ${output_maindir}

./runtime.sh "${start_time}"
echo "done"

exit 0
