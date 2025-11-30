#!/bin/sh
#$ -m be
#$ -cwd
#$ -pe threads 6

function usage() {
    cat <<'EOF'
============================================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20170804
    History: 20200415
    History: 20231005 (update kaiju v1.9.2 & nrEuk2023-05-10)
    History: 20231005
    History: 20251008 (change output paths, add database refseq_nr2024-08-14
    - thread:16
    - Kaiju taked a lot of memory space: >150Gb for NR_euk database.
Database:
    - NrEuk
    - GORG (marine single-cell derived datasaet)
Usage:
    this.sh  fastA/Q  [RefSeqNr,NrEuk,GORG]  [threads=16]

-------------------------------------------------------
Make kaiju database
see: https://github.com/bioinformatics-centre/kaiju
This process takes a lot of memory space!  (>220 GB)
-------------------------------------------------------
    cd ${HOME}/database
    mkdir kaiju
    cd kaiju
    ${HOME}/workspace/software/kaiju-v1.8.2-linux-x86_64-static/kaiju-makedb -s nr_euk
- or
    ./qsub_epyc.sh 1 wget https://kaiju-idx.s3.eu-central-1.amazonaws.com/2023/kaiju_db_nr_euk_2023-05-10.tgz --no-check-certificate
============================================================================================================================================================
EOF
    return 0
}   

# tool----------------------------------------------------------------------------------------------
#kaiju="        ${HOME}/workspace/software/kaiju-v1.8.2-linux-x86_64-static/kaiju"
#kaiju2krona="  ${HOME}/workspace/software/kaiju-v1.8.2-linux-x86_64-static/kaiju2krona"
#kaijuReport="  ${HOME}/workspace/software/kaiju-v1.8.2-linux-x86_64-static/kaiju2table"
#addTaxonNames="${HOME}/workspace/software/kaiju-v1.8.2-linux-x86_64-static/kaiju-addTaxonNames"
kaiju="        ${HOME}/workspace/software/kaiju-1.9.2/bin/kaiju"
kaiju2krona="  ${HOME}/workspace/software/kaiju-1.9.2/bin/kaiju2krona"
kaijuReport="  ${HOME}/workspace/software/kaiju-1.9.2/bin/kaiju2table"
addTaxonNames="${HOME}/workspace/software/kaiju-1.9.2/bin/kaiju-addTaxonNames"
database_pass="${HOME}/database/kaiju/"

# database----------------------------------------------------------------------------------------------
MODE_refseqnr="RefSeqNr"
database_RefSeqNr_node="${database_pass}/kaiju_RefSeqNr_20240813/nodes.dmp"
database_RefSeqNr_name="${database_pass}/kaiju_RefSeqNr_20240813/names.dmp"
database_RefSeqNr_fami="${database_pass}/kaiju_RefSeqNr_20240813/kaiju_db_refseq_nr.fmi"

MODE_NrEuk="NrEuk"
database_NrEuk_node="${database_pass}/kaiju_20230510/nodes.dmp"
database_NrEuk_name="${database_pass}/kaiju_20230510/names.dmp"
database_NrEuk_fami="${database_pass}/kaiju_20230510/kaiju_db_nr_euk.fmi"

MODE_gorg="GORG"
database_GORG_node="${database_pass}/GORG_v1_NCBInodes.dmp"
database_GORG_name="${database_pass}/GORG_v1_NCBInames.dmp"
database_GORG_fami="${database_pass}/GORG_v1_NCBI.fmi"
#----------------------------------------------------------------------------------------------

threads=16
start_time=`date +%s`
OutputDir_root=../taxonomyAssignment

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

if   [ $# -gt 1 ]; then
    if   [ ${2} = "RefSeqNr" ]; then
        database_node=${database_RefSeqNr_node}
        database_name=${database_RefSeqNr_name}
        database_fami=${database_RefSeqNr_fami}
        MODE=${MODE_refseqnr}
    elif [ ${2} = "NrEuk" ]; then
        database_node=${database_NrEuk_node}
        database_name=${database_NrEuk_name}
        database_fami=${database_NrEuk_fami}
        MODE=${MODE_NrEuk}
    elif   [ ${2} = "GORG" ]; then
        database_node=${database_GORG_node}
        database_name=${database_GORG_name}
        database_fami=${database_GORG_fami}
        MODE=${MODE_gorg}
    else
        echo "Undefiended mode: ${2}"
        usage
        exit 1   
    fi
fi
echo "Mode: ${MODE}"

if [ $# -gt 2 ]; then
    echo "thread: ${3}"
    threads=${3}
fi

FILENAME=${1##*/}
BASE_FILENAME=${FILENAME%.*}
DIRNAME_PATH=$(dirname ${1})
DIRNAME_UP=${DIRNAME_PATH##*/}
DIRENAME_UPPATH=$(dirname ${DIRNAME_PATH})
DIRNAME_UPUP=${DIRENAME_UPPATH##*/}

if [ ${DIRNAME_UPUP} = "assembly" ]; then  #canu
    BASE_FILENAME=${DIRNAME_UP}
fi

#add mode
BASE_FILENAME=Kaiju${MODE}_${BASE_FILENAME}
echo ${BASE_FILENAME}

OUTPUT_PATH=${OutputDir_root}/${BASE_FILENAME}
if [ ! -e ${OUTPUT_PATH} ]; then
    mkdir ${OUTPUT_PATH} -p
fi

OUTPUT_FILE=${OUTPUT_PATH}/${BASE_FILENAME}.out

#----------------------------------------------------------------------------------------------
#search
#----------------------------------------------------------------------------------------------
if [ ! -e ${OUTPUT_FILE} ]; then
    command="${kaiju} \
            -z ${threads} \
            -t ${database_node} \
            -f ${database_fami} \
            -i ${1} \
            -o ${OUTPUT_FILE} \
            -a greedy -e 5" 
    echo ${command}
    eval ${command}

    #./taxonomy_kaiju-report.sh ${OUTPUT_PATH}/kaiju_${BASE_FILENAME}.out
else
    echo "kaiju passes."
fi
 
#----------------------------------------------------------------------------------------------
#report
#----------------------------------------------------------------------------------------------
if [ ! -e ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.summary.phylum.tsv ]; then
    ${kaiju2krona}   -v -t ${database_node} -n ${database_name}            -o ${OUTPUT_PATH}/${BASE_FILENAME}.krona                    -i ${OUTPUT_FILE}

    #taxono summary (calculate rerative abundances)
    ${kaijuReport}   -v -t ${database_node} -n ${database_name} -r phylum  -o ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.summary.phylum.tsv   ${OUTPUT_FILE}
    ${kaijuReport}   -v -t ${database_node} -n ${database_name} -r class   -o ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.summary.class.tsv    ${OUTPUT_FILE}
    ${kaijuReport}   -v -t ${database_node} -n ${database_name} -r order   -o ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.summary.order.tsv    ${OUTPUT_FILE}
    ${kaijuReport}   -v -t ${database_node} -n ${database_name} -r family  -o ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.summary.family.tsv   ${OUTPUT_FILE}
    ${kaijuReport}   -v -t ${database_node} -n ${database_name} -r genus   -o ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.summary.genus.tsv    ${OUTPUT_FILE}
    ${kaijuReport}   -v -t ${database_node} -n ${database_name} -r species -o ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.summary.species.tsv  ${OUTPUT_FILE}

    #readID-taxon
    ${addTaxonNames} -v -t ${database_node} -n ${database_name}    -p      -o ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.names.FULL.tsv    -i ${OUTPUT_FILE}
    ${addTaxonNames} -v -t ${database_node} -n ${database_name} -r phylum  -o ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.names.phylum.tsv  -i ${OUTPUT_FILE}
    ${addTaxonNames} -v -t ${database_node} -n ${database_name} -r class   -o ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.names.class.tsv   -i ${OUTPUT_FILE}
    ${addTaxonNames} -v -t ${database_node} -n ${database_name} -r order   -o ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.names.order.tsv   -i ${OUTPUT_FILE}
    ${addTaxonNames} -v -t ${database_node} -n ${database_name} -r family  -o ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.names.family.tsv  -i ${OUTPUT_FILE}
    ${addTaxonNames} -v -t ${database_node} -n ${database_name} -r genus   -o ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.names.genus.tsv   -i ${OUTPUT_FILE}
    ${addTaxonNames} -v -t ${database_node} -n ${database_name} -r species -o ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.names.species.tsv -i ${OUTPUT_FILE}

    #domain
     cat ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.names.FULL.tsv   |cut -f-2 -d ";" |sed -e "s/cellular organisms; //g" |cut -f-1 -d ";" > ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.names.domain.tsv
    #cat ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.names.domain.tsv |cut -f4 |sort |uniq -c |awk '{print "dummy\t0\t" $1 "\t0\t" $2}'     > ${OUTPUT_PATH}/${BASE_FILENAME}.kairep.summary.domain.tsv

fi

echo "all done"
./runtime.sh ${start_time}

exit 0
