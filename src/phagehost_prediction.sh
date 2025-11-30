#!/bin/sh
#$ -m be
#$ -cwd
#$ -pe threads 6

function usage() {
    cat <<'EOF'
========================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20220621
    History: 20220621
    - PHIST
    - https://github.com/refresh-bio/phist

    currentry not work.

Usage:
    ./phagehost_prediction.sh fastQ
========================================================================================================================================
EOF
    return 0
}   


phyloshift="${HOME}/software/phylosift_20140419/phylosift"
threads=6

if [ $# -ne 1 ]; then
    echo "Error: Please set two options; 'database path' and 'query file'"
    usage
    exit 1
fi

exit 1 


#PHIST

python3 phist.py ./example/virus ./example/host ./out/common_kmers.csv ./out/predictions.csv

python3 ${HOME}/software/PHIST/phist.py ../ViralGenome/V-MAGs_DSSMv0.2/ ../binning/DSSMv0.2_metawrap_mdmcleaner_+_vamb/ ../phage-host/common_kmers.csv ../phage-host/predictions.csv

python3 ${HOME}/software/PHIST/phist.py ${HOME}/workspace/_NakabusaHotSpring_metaepigenomics/V-MAGs/ ../binning/DSSMv0.2_metawrap_mdmcleaner_+_vamb/ ../phage-host/common_kmers.csv ../phage-host/predictions.csv




#CrisprOpenDB
conda activate CrisprOpenDB_env


python ${HOME}/software/CrisprOpenDB/CL_Interface.py -i Salmonella_161.fasta -m 2

python ${HOME}/software/CrisprOpenDB/CL_Interface.py -i V-MAGs/VMAG_S-GRN_bin64.fa -m 2 -b ${HOME}/software/CrisprOpenDB/CrisprOpenDB/SpacersDB/SpacersDB

cd ${HOME}/software/CrisprOpenDB/
python CL_Interface.py -i ${HOME}/workspace/_NakabusaHotSpring_metaepigenomics/V-MAGs.fa -m 2 -b CrisprOpenDB/SpacersDB/SpacersDB --num_threads 20  > ${HOME}/workspace/_NakabusaHotSpring_metaepigenomics/CrisprOpenDB.tsv






#DeepHost
conda activate py38

python DeepHost.py -h


python ${HOME}/software/DeepHost/DeepHost_scripts/DeepHost.py ../example/test_data.fasta --multiple True --thread 10


















FILENAME=${1##*/}
BASE_FILENAME=${FILENAME%.*}
DIRNAME_PATH=$(dirname ${1})
DIRNAME_UP=${DIRNAME_PATH##*/}
DIRENAME_UPPATH=$(dirname ${DIRNAME_PATH})
DIRNAME_UPUP=${DIRENAME_UPPATH##*/}

if [ ${DIRNAME_UPUP} = "assembly" ]; then  #canu
    BASE_FILENAME=${DIRNAME_UP}
fi
echo ${BASE_FILENAME}

#${phyloshift} search --threads ${threads} --debug            --output ../phyloshift/${str_dirname} ${1} >  ../phyloshift/${str_dirname}.log 2> ../phyloshift/${str_dirname}.err

#${phyloshift} align  --threads ${threads} --debug --continue --output ../phyloshift/${str_dirname} ${1} >> ../phyloshift/${str_dirname}.log 2> ../phyloshift/${str_dirname}.err

command="${phyloshift} all  --threads ${threads} --output ../phylosift/${BASE_FILENAME} ${1}"
echo ${command}
${command}