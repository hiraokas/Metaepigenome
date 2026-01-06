#!/bin/bash
#$ -m be
#$ -cwd

function usage() {
    cat <<'EOF'
==================================================================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20210204
    History: 20210204
    History: 20230526  #virsorter=2.2.4
    History: 20250606 (re-install)
    History: 20251228
    - Viral genome prediction from genomic data using VirSorter
    - See: https://github.com/jiarong/VirSorter2
Require:
    conda environment (virsorter2)
Usage:
    conda activate virsorter2
    ./virsorter2.sh conting.fasta [thread=30]
Tips:
    for f in ../contigs/split/SPAdes_PE-Merged_IO1-*.fasta; do bash -c "nohup ./virsorter2.sh ${f} 2 &"; done
    for f in ../assembly/SPAdes_[A-I]*.fasta; do ./qsub_da.sh 30 ./virsorter2.sh ${f} 38; done
----------------------------------------------------------
Install (troublesome):
    # # 20250605 at ES
    git clone https://github.com/jiarong/VirSorter2.git
    # wget https://github.com/jiarong/VirSorter2/archive/refs/tags/v2.2.4.tar.gz  # ORD!!!!!!!! SHOULD USE GIT VERSION
    conda  env create -n vs2 -f vs2-external-deps.yaml
    pip install -e .
    conda install bioconda::screed

    # 20250605 at ES, using singlarity
    #conda activate vs2
    #apptainer build virsorter2.sif docker://jiarong/virsorter:latest

    # - Online connection is required.
    # #conda create -n vs2 -c conda-forge -c bioconda virsorter=2
    # #conda activate vs2

    # in case with " --use-conda-off" option. This will nesessary to run at ES cluster nodess, i.e., qsub run.
    conda install  hmmer==3.3 numpy pandas joblib scikit-learn==0.22.1 imbalanced-learn seaborn last -c bioconda  -c conda-forge # click 

    # conda create -n virsorter2 -c conda-forge -c bioconda "python>=3.6,<=3.10" scikit-learn=0.22.1 imbalanced-learn pandas seaborn hmmer==3.3 prodigal screed ruamel.yaml "snakemake>=5.18,<=5.26" click "conda-package-handling<=1.9"
    # conda activate virsorter2
    # cd ~/workspace/software/
    # #git clone https://github.com/jiarong/VirSorter2.git
    # cd VirSorter2
    # pip install -e .

    #snakemake profile
    #cookiecutter https://github.com/Snakemake-Profiles/sge.git
    cookiecutter https://github.com/Snakemake-Profiles/generic.git

    cat << 'EOF'
====================
# non-slurm profile defaults
restart-times: 3
#local-cores: 1
latency-wait: 60
use-conda: True
jobs: 1
keep-going: True
rerun-incomplete: True
# shadow-prefix: /scratch/ntpierce
printshellcmds: True
====================
    EOF

SetUp and test run :
    #setup virsorter database and configulation
    rm -r ~/database/VirSorter2/*
    virsorter     setup -d ${HOME}/database/VirSorter2 -j 8
    #./virsorter2.sif setup -d ${HOME}/database/VirSorter2 -j 8    
    virsorter     config --set HMMSEARCH_THREADS=20   
    virsorter     config --set LOCAL_SCRATCH=${HOME}/local/tmp   
    #./virsorter2.sif config --set HMMSEARCH_THREADS=20   

    #singularity shell virsorter2.sif
    #test
    wget -O test.fa https://raw.githubusercontent.com/jiarong/VirSorter2/master/test/8seq.fa
    virsorter run -w test.out -i test.fa --min-length 1500 -j 4 all
==================================================================================================================================================================================
EOF
    return 0
}   

#----------------------------------------------------------------------------
source ${HOME}/miniconda3/etc/profile.d/conda.sh
#conda activate virsorter2
conda activate vs2
snakemake_profile="${HOME}/workspace/software/VirSorter2/default"
#snakemake_profile="${HOME}/workspace/software/VirSorter2/cluster"
#snakemake_profile="${HOME}/workspace/software/VirSorter2/sge"

#for ES system
#module load singularity  
#singularity exec virsorter2.sif virsorter -h

Output_dir="../virsorter2/"
database=${HOME}/database/VirSorter2
threads=30
#contig_min=1000
#----------------------------------------------------------------------------

if [ $# -lt 1 ]; then
    echo "Error: Please set two options; 'database path' and 'query file'"
    usage
    exit 1
fi

fasta=${1}
str_filename=${1##*/}
str_filename_we=${str_filename%.*}
output_path=${Output_dir}/${str_filename_we}.out

if [ $# -gt 1 ]; then
    threads=${2}
fi

echo "====INFORMATION============================================================"
conda info -e
echo ""
echo "Output dir: ${output_path}"
echo "Current dir: " `pwd`
which virsorter
which snakemake
echo "statistics: snakemake.stat.tsv"
cat  snakemake.stat.tsv
echo ""
echo $*
echo "Thread: ${2}"
echo "==========================================================================="

#-------------------------------------------------------------
#run virsorter
# min length is according to the original paper
# --use-conda-off   option should be harmfull (20230608)
#-------------------------------------------------------------
virsorter_Path=`which virsorter`
command="virsorter run all -w ${output_path} -i ${fasta} --cores ${threads} --min-length 3000 --verbose -d ${database} --use-conda-off" # --forceall  --profile ${snakemake_profile}  --tmpdir tmp  --profile cluster #-d ${database} 
echo ${command}
${command}

#clean up
#rm ${output_path}/iter-0 -r

echo "Output file: ${output_path}"
echo "All done."
