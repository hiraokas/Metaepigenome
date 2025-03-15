#!/bin/sh
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
    History: 20230609
    - See: https://github.com/jiarong/VirSorter2
Usage:
    conda activate virsorter2
    ./virsorter2.sh conting.fasta [thread=30]
Tips:
    for f in ../contigs/split/SPAdes_PE-Merged_IO1-*.fasta; do bash -c "nohup ./virsorter2.sh ${f} 2 &"; done
    for f in ../contigs/contigs/SPAdes_PE-Merged_[I]*; do ./qsub_da.sh 30 ./virsorter2.sh ${f} 38; done
    for f in ../assembly/SPAdes_[A-I]*.fasta; do ./qsub_da.sh 30 ./virsorter2.sh ${f} 38; done
----------------------------------------------------------
Install (troublesome):
    - Online connection is required.
    #conda create -n virsorter2  -c bioconda virsorter=2  #.2.4
    #conda activate virsorter2

    #conda create -n virsorter2 python=3.8
    #conda activate virsorter2
    #conda install screed prodigal snakemake hmmer==3.3  imbalanced-learn pandas seaborn click scikit-learn  -c bioconda 
    #conda install ruamel.yaml 

    conda create -n virsorter2 -c conda-forge -c bioconda "python>=3.6,<=3.10" scikit-learn=0.22.1 imbalanced-learn pandas seaborn hmmer==3.3 prodigal screed ruamel.yaml "snakemake>=5.18,<=5.26" click "conda-package-handling<=1.9"
    conda activate virsorter2
    #git clone https://github.com/jiarong/VirSorter2.git
    cd VirSorter2
    pip install -e .

    #setup virsorter database and configulation
    virsorter setup -d ${HOME}/database/VirSorter2 -j 8
    virsorter config --set HMMSEARCH_THREADS=20   
==================================================================================================================================================================================
EOF
    return 0
}   

source ${HOME}/miniconda3/etc/profile.d/conda.sh
conda activate virsorter2

#for ES system
#module load singularity  
#singularity exec virsorter2.sif virsorter -h

Output_dir="../virsorter2/"
database=${HOME}/database/VirSorter2
threads=30
#contig_min=1000

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
cat snakemake.stat.tsv
echo ""
echo $*
echo "Thread: ${2}"
echo "==========================================================================="

#-------------------------------------------------------------
#run virsorter
#min length is according to the original paper
# --use-conda-off   option should be harmfull (20230608)
#-------------------------------------------------------------
#virsorter run all -w ../virsorter2//hifiasmMeta_hifi_M362.hifi.contig.out -i ../assembly/hifiasmMeta_hifi_M362.hifi.contig.fa --cores 6 --min-length 3000 --verbose -d /S/home00/G3516/p0783/database/VirSorter2
#virsorter run -w test.out -i test.fa --min-length 1500 -j 4 all
command="virsorter run all -w ${output_path} -i ${fasta} --cores ${threads}  --min-length 3000  --verbose -d ${database} #--tmpdir tmp  --profile cluster #-d ${database} --use-conda-off"  
echo ${command}
${command}
#     virsorter run all -w ${output_path} -i ${fasta} --cores ${threads}  --min-length 3000  --verbose -d ${database} #--tmpdir tmp  --profile cluster #-d ${database} --use-conda-off 

#clean up
#rm ${output_path}/iter-0 -r

echo "Output file: ${output_path}"
echo "All done."
