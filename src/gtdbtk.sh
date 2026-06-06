#!/bin/bash
#$ -m be
#$ -cwd
#$ -pe threads 6

function usage() {
    cat <<'EOF'
========================================================================================================================================
Description
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20220430
    History: 20230418 (update 2.2.6)
    History: 20230609 (add de_novo_wf mode)
    History: 20230610 (update 2.3.0 with release214)
    History: 20240521 (update 2.4.0 with release220)
    History: 20250528 (update            release226, v2.4.1 was not work well in ES system)
    History: 20260428 (update 2.7.1 with release232)
    History: 20260514 (update 2.7.2 with release232, change mode name and dir path)
    - A wrapper of GTDB-Tk for taxonomic assignment of genomes.
    - https://github.com/Ecogenomics/GTDBTk
    - gtdb-tk takes a lot of memory space (typically <60 GB, ~880 GB in ES system).
        - officially, 150 GB per threads are required by pplacer
    - outputdir: ../taxonomyAssignment/
Install:
    see -H option
Usage:
    this.sh classify_wf          dir_pass [thread=6]   #for classify your MAGs
    this.sh de_novo_wf_bacteria  dir_pass [thread=6]
    this.sh de_novo_wf_archaea   dir_pass [thread=6]
    this.sh -H
    this.sh -T [dummy] [thread=6]
Tips:
    ./gtdbtk.sh ../vamb_DSSMv0.2_concatenate/vamb_DSSMv0.2_concatenate/ 20
    ./qsub_DDBJ.sh medium 10 20 20 ./gtdbtk.sh -T dummy 10
    ./qsub_DDBJ.sh medium 20 8 20 ./gtdbtk.sh ../my_binning/P-MAGs_v0.1/ 20
    ./qsub_mem_da.sh 40 ./gtdbtk.sh ../binning/DSSMv0.2_metawrap 40
    ./qsub_medium.sh 20 ./gtdbtk.sh ../my_binning/P-MAGs_v0.1/ 20
========================================================================================================================================
EOF
    return 0
}

function install() {
    cat <<'EOF'
========================================================================================================================================
Install:
    - See:  https://github.com/Ecogenomics/GTDBTk
    - Also: https://ecogenomics.github.io/GTDBTk/installing/index.html

    #conda install -c bioconda gtdbtk==2.3.0
    #conda create -n gtdbtk-2.3.0 -c conda-forge -c bioconda gtdbtk=2.3.0  #sould specify version
    #conda create -n gtdbtk-2.4.1 -c conda-forge -c bioconda gtdbtk=2.4.1  # r226
     conda create -n gtdbtk-2.7.2 -c conda-forge -c bioconda gtdbtk=2.7.2  # r232
    conda activate gtdbtk-2.7.2
    conda env config vars set GTDBTK_DATA_PATH=${HOME}/database/GTDB-Tk/release232/

    #multiprocessing
    #conda install conda-forge::multiprocess
    #conda install numpy==2.2.6 # downgrade to be adjusted to gtdbtk-2.4.1
    #conda install -c bioconda skani=0.3.1  #downgrade for ES system

    #tensorflow
    #pip install tensorflow

    #DB preparation
    #wget https://data.gtdb.ecogenomic.org/releases/latest/auxillary_files/gtdbtk_data.tar.gz
    wget https://data.ace.uq.edu.au/public/gtdb/data/releases/latest/auxillary_files/gtdbtk_package/full_package/gtdbtk_data.tar.gz
    tar xvzf gtdbtk_data.tar.gz

    #check
    conda activate gtdbtk-2.7.2
    database=${HOME}/database/GTDB/release232/
    export GTDBTK_DATA_PATH=${database}
    gtdbtk check_install

    rm -r OUT_DIR
    gtdbtk test --out_dir OUT_DIR --cpus 10
    gtdbtk classify_wf --place_species --genome_dir OUT_DIR/genomes --out_dir OUT_DIR/output --cpus 10 -f --extention fa
========================================================================================================================================
EOF
    return 0
}   

usage_exit() {
    usage
    exit 1
}

if [ $# -lt 1 ]; then
    echo "Insufficient parameters"
    usage
    exit 1
fi

mode=${1}
targetDir=${2}
OutputDir_root=../taxonomyAssignment
thread=6

if [ $# -gt 2 ]; then
    thread=${3}
fi

if [ ${mode} == "-H" ]; then
    install
    exit 1
fi

if [ ! -e ${output_dir} ]; then
    mkdir ${output_dir}
fi

#------------------------------------------------------------------
source ${HOME}/miniconda3/etc/profile.d/conda.sh
#conda activate gtdbtk-2.4.1
#conda activate gtdbtk-2.7.1
conda activate gtdbtk-2.7.2

#database=${HOME}/database/GTDB/release220/ ; DBversion="R220"
#database=${HOME}/database/GTDB/release226/ ; DBversion="R226"
 database=${HOME}/database/GTDB/release232/ ; DBversion="R232"
export GTDBTK_DATA_PATH=${database}
#------------------------------------------------------------------

#for DDBJ
#module load tensorflow2-py36-cuda10.1-gcc/2.0.0

Dirpass=`echo ${targetDir}| sed -e "s/\/$//g"`
DirpassBase=${Dirpass##*/}
OutputDir_prefix=${mode}_${DirpassBase}_${DBversion}
OutputDir=${OutputDir_root}/${OutputDir_prefix}

echo "============================================================"
which gtdbtk
which prodigal
which FastTreeMP
echo "Current dir: "`pwd`
echo "mode:      ${mode}"
echo "targetDir: ${targetDir}"
echo "Database:  ${database}"
echo "GTDBTK_DATA_PATH: ${GTDBTK_DATA_PATH}"
echo "Threads:   ${thread}"
echo "OutputDir: ${OutputDir}"
echo "============================================================"

if [ ${mode} == "-T" ]; then
    echo "Test mode"
    rm -r ${OutputDir_root}/test
    gtdbtk test --out_dir ${OutputDir_root}/test  --cpus ${thread} 
    exit 0
fi

#check extention
ext=`ls ${targetDir}/ | head -1 | rev | cut -f1 -d "."| rev`
echo "Auto-detedted extention: ${ext}"

#run
mkdir -p ${OutputDir}/tmp/
if [ ${mode} == "classify_wf" ]; then 
    gtdbtk classify_wf --genome_dir ${Dirpass}/ --extension ${ext} --out_dir ${OutputDir} --cpus ${thread} --force \
        --scratch_dir ${OutputDir}/scratch/ 
        # --tmpdir      ${OutputDir}/tmp/ \  # not work since gtdb-tk 2.7.1
        # --debug --full_tree 
        # --place_species \
        # --mash_db ${OutputDir}  # gtdb-tk 2.4.1

elif [ ${mode} == "de_novo_wf_bacteria" ]; then
    outgroup="p__Patescibacteriota"
    if [ ${DBversion} == "R220" ]; then
        outgroup="p__Patescibacteria"
    fi

    gtdbtk de_novo_wf  --genome_dir ${Dirpass}/ --extension ${ext} --out_dir ${OutputDir} --keep_intermediates \
        --force --tmpdir ${OutputDir}/tmp/ --bacteria --debug  --outgroup_taxon ${outgroup} --cpus ${thread}     #but try (20241007)
         #--tmpdir ${OutputDir}/tmp/   --bacteria --debug  --outgroup_taxon p__Patescibacteria #--cpus ${thread}   #THREADS setting will not be worked under qsub (well work under qlogin environment, reason unclear) (20230611)

elif [ ${mode} == "de_novo_wf_archaea" ]; then
    gtdbtk de_novo_wf  --genome_dir ${Dirpass}/ --extension ${ext} --out_dir ${OutputDir} --keep_intermediates \
        --force --tmpdir ${OutputDir}/tmp --archaea   --debug --outgroup_taxon p__Altiarchaeota --cpus ${thread}
         #--tmpdir ${OutputDir}/tmp/   --archaea  --debug --outgroup_taxon p__Altiarchaeota #--cpus ${thread}
else
    echo "Illigal mode: ${mode}"
    exit 1
fi

# merge output file
cat ${OutputDir}/gtdbtk.{bac,ar}*.summary.tsv | sort > ${OutputDir}/gtdbtk.all.summary.tsv
cat ${OutputDir}/gtdbtk.{bac,ar}*.summary.tsv | sort > ${OutputDir_root}/${OutputDir_prefix}.tsv

# clean---------------------------------------
echo "Clean tmeporaly files/dirs"
#rm -r ${OutputDir}/align  # this will be used for phylogenetic tree construction, so do not remove
rm -r ${OutputDir}/tmp/
rm -r ${OutputDir}/*/intermediate_results
rm    ${OutputDir}/gtdb_ref_sketch.msh

exit 0
