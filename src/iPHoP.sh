#!/bin/bash

function usage() {
    cat <<'EOF'
==================================================================================================================================================================================
Description
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20220903
    History: 20240924 #database update: 2023Aug
    History: 20251223
    - A wrapper of iPHoP to predict host-phage interaction using genomic information. 
    - https://bitbucket.org/srouxjgi/iphop/src/main/
    - This workflow conposed with multiple tools. Please check log files (XXX.log under the output dir) carefully when some troubles occured.
Require
    conda envirpnment (iphop)
Usage:
    this.sh viral.fasta [threads=10] [database_path]
Output dir:
    ../HostPrediction/
Tips:
    for f in ../ViralGenome/2_V-MAGs_hifiasm-meta-v0.2_rename/V-MAGs_S-BL*.fa; do ./qsub_short.sh  8 ./iPHoP.sh ${f}; done
    ./iPHoP.sh ../DSSM/DSSMv0.2/DSSMv0.2_V-MAGs.fa 
Install:
    #----------------------------------
    #manual install 2024/2025
    #----------------------------------
    conda activate iphop
    git clone https://bitbucket.org/srouxjgi/iphop.git
    cd iphop
    #conda install  iphop_environment.yml
    git lfs install
    git lfs pull
    python -m pip install https://files.pythonhosted.org/packages/72/8a/033b584f8dd863c07aa8877c2dd231777de0bb0b1338f4ac6a81999980ee/tensorflow-2.7.0-cp38-cp38-manylinux2010_x86_64.whl -vv
    python -m pip install https://files.pythonhosted.org/packages/2a/78/bf49937d0d9a36a19faca28dac470a48cfe4894995a70e73f3c0c1684991/tensorflow_decision_forests-0.2.2-cp38-cp38-manylinux_2_12_x86_64.manylinux2010_x86_64.whl -vv
    python -m pip install .
    conda install -c bioconda perl-bioperl  # Bio::SeqIO
    pip uninstall pandas
    conda install pandas==1.3 -c conda-forge  #pandas should be 1.3, not >2 and 1.5.3

    #----------------------------------
    # conda sintall 
    # (well work, but take >1h to resolve conda environment...: 202409)
    # (not work: 20250424)
    #----------------------------------
    conda create -n iphop python=3.8 
    conda activate iphop
    conda install iphop=1.3.3 -c conda-forge -c bioconda 

    #----------------------------------
    # manual install 2023
    #----------------------------------
    # git clone https://bitbucket.org/srouxjgi/iphop.git
    # cd iphop
    # conda env create -f iphop_environment.yml  #or can be edit to change the environment name iphop -> iphop2, for example.
    # conda activate iphop
    # git lfs install
    # git lfs pull
    # python -m pip install https://files.pythonhosted.org/packages/72/8a/033b584f8dd863c07aa8877c2dd231777de0bb0b1338f4ac6a81999980ee/tensorflow-2.7.0-cp38-cp38-manylinux2010_x86_64.whl -vv
    # python -m pip install https://files.pythonhosted.org/packages/2a/78/bf49937d0d9a36a19faca28dac470a48cfe4894995a70e73f3c0c1684991/tensorflow_decision_forests-0.2.2-cp38-cp38-manylinux_2_12_x86_64.manylinux2010_x86_64.whl -vv
    # python -m pip install .
    # conda install -c bioconda perl-bioperl  # Bio::SeqIO

    # for ES system (use default perl, not conda perl, for RaFAH) (This will not well work because bioperl will still need conda-version perl.)
    # ##### conda uninstall perl

    # #libsnl for ES system
    # wget https://github.com/thkukuk/libnsl/releases/download/v2.0.0/libnsl-2.0.0.tar.xz
    # ./configure --sysconfdir=/etc --disable-static --prefix=${HOME}/local
    # make -J 10
    # make install

Database prep
    # using provided official database
    conda activate iphop
    mkdir ${HOME}/database/iPHoP/iPHoP_2023Aug23
    iphop download --db_dir ${HOME}/database/iPHoP/iPHoP_2023Aug23  #this will takes >2h
    iphop download --db_dir ${HOME}/database/iPHoP/iPHoP_2023Aug23 --full_verify

Database prep (manual addition of my P-MAGs with GTDB)
    # cd ~/database/iPHop_20230608
    # wget https://bitbucket.org/srouxjgi/iphop/downloads/Data_test_add_to_db.tar.gz
    # tar -xvf Data_test_add_to_db.tar.gz
    # ls Data_test_add_to_db

    conda activate gtdbtk-2.3.0
    #gtdbtk de_novo_wf --genome_dir ../DSSM/DSSMv0.2/DSSMv0.2_HQrep/ --bacteria  --out_dir ../gtdbtk/bacteria/ --cpus 10  --extension fa --outgroup_taxon p__Patescibacteria
    #gtdbtk de_novo_wf --genome_dir ../DSSM/DSSMv0.2/DSSMv0.2_HQrep/ --archaea   --out_dir ../gtdbtk/archaea/  --cpus 10  --extension fa --outgroup_taxon p__Altiarchaeota  
    # - OUTgroup SHOULd be changed due to the nomenculate changes of many phylum

    ./qsub_DDBJ.sh medium 10 20 40 ./gtdbtk.sh de_novo_wf_bacteria ../DSSM/DSSMv0.2/DSSMv0.2_HQrep/ 10
    ./qsub_DDBJ.sh medium 10 20 40 ./gtdbtk.sh de_novo_wf_archaea  ../DSSM/DSSMv0.2/DSSMv0.2_HQrep/ 10
    # ./qsub_ES.sh   gpu   1 1 48 ./gtdbtk.sh de_novo_wf_bacteria  ../my_binning/P-MAGv0.4_chromosome/ 16
    # ./qsub_ES.sh   gpu   1 1 48 ./gtdbtk.sh de_novo_wf_archaea   ../my_binning/P-MAGv0.4_chromosome/ 16

    #gather
    mv ../GTDB-Tk/de_novo_wf_archaea_P-MAGv0.4_chromosome/*   ../GTDB-Tk/de_novo_wf_ALL_P-MAGv0.4_chromosome/
    mv ../GTDB-Tk/de_novo_wf_bacteria_P-MAGv0.4_chromosome/*  ../GTDB-Tk/de_novo_wf_ALL_P-MAGv0.4_chromosome/

    iphop add_to_db --fna_dir ../my_binning/P-MAGv0.4_chromosome/ --gtdb_dir ../GTDB-Tk/de_novo_wf_ALL_P-MAGv0.4_chromosome/ --out_dir ${HOME}/database/iPHop_20230608/mpt_2021_pub_rw/

Test run
    conda activate iphop
    export LD_LIBRARY_PATH=${HOME}/local/lib:${HOME}/miniconda3/lib:$LD_LIBRARY_PATH
    export PERL5LIB=${HOME}/miniconda3/envs/iphop/lib/perl5/site_perl/5.22.0/:${PERL5LIB}
    iphop predict --debug --fa_file ${HOME}/workspace/software/iphop/test/test_input_phages.fna --db_dir ${HOME}/database/iPHoP/iPHoP_2023Aug23/Aug_2023_pub_rw/ \
    --out_dir test_input_phages_iphop_origin  --num_threads 16 

==================================================================================================================================================================================
EOF
    return 0
}   

#---------------------------------------------------------------------
database=${HOME}/database/iPHoP/iPHoP_2023Aug23/Aug_2023_pub_rw
output_dir=../HostPrediction/
threads=10
#---------------------------------------------------------------------

if [ $# -lt 1 ]; then
    echo "Error: Please set file(s)"
    usage
    exit 1
fi

if [ $# -gt 1 ]; then
    threads=${2}
fi

if [ $# -gt 2 ]; then
    database=${3}
fi

FILENAME=${1##*/}
BASE_FILENAME=${FILENAME%.*}
DBNAME=${database##*/}
BASE_DBNAME=${DBNAME%.*}

OUTPUT_path=${output_dir}/iPHoP_${DBNAME}_${BASE_FILENAME}

#---------------------------------------------------------------------
source ${HOME}/miniconda3/etc/profile.d/conda.sh
conda activate iphop 

#need for rafah run
export PATH=${HOME}/local/bin:$PATH
export LD_LIBRARY_PATH=${HOME}/local/lib:${HOME}/anaconda3-2/lib:$LD_LIBRARY_PATH
export PERL5LIB=${HOME}/miniconda3/envs/iphop/lib/perl5/site_perl/5.22.0/:${PERL5LIB}
#---------------------------------------------------------------------

#log
echo "============================================================"
echo "Threads:         ${threads}"
echo "Database:        ${database}"
echo "OUTPUT_path:     ${OUTPUT_path}"
echo "blast:           `which blastn`"
echo "PATH:"           ${PATH}
echo "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH}"
echo "PERL5LIB:        ${PERL5LIB}"
echo "============================================================"

if [ -e  ${OUTPUT_path} ]; then
    echo "Output Dir exist: ${OUTPUT_path}"
    #continue
else
    echo "${FILENAME} -> ${OUTPUT_path}"
fi

iphop predict --fa_file ${1} --db_dir ${database} --out_dir ${OUTPUT_path} --num_threads ${threads} --debug

#rm -r ${OUTPUT_path}/Wdir
echo "Output:  ${OUTPUT_path}"
echo "Done."

exit 0

