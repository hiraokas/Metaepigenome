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
    - thread:16
    - Kaiju taked a lot of memory space: >150Gb for NR_euk database.
Database:
    - NrEuk
    - GORG (marine single-cell derived datasaet)
Usage:
    this.sh  fastA/Q  [NrEuk,GORG]  [threads=16]

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
MODE_nr="NrEuk"
#database_node="${database_pass}kaiju_20211123/nodes.dmp"
#database_name="${database_pass}kaiju_20211123/names.dmp"
#database_fmi=" ${database_pass}kaiju_20211123/kaiju_db_nr_euk.fmi"
database_node="${database_pass}kaiju_20230510/nodes.dmp"
database_name="${database_pass}kaiju_20230510/names.dmp"
database_fmi=" ${database_pass}kaiju_20230510/kaiju_db_nr_euk.fmi"

MODE_gorg="GORG"
#database_node_GORG="${database_pass}GORG_v1_CRESTnodes.dmp"  #silva mode
#database_name_GORG="${database_pass}GORG_v1_CRESTnames.dmp"  #silva mode
#database_fmi_GORG=" ${database_pass}GORG_v1_CREST.fmi"  #silva mode
database_node_GORG="${database_pass}GORG_v1_NCBInodes.dmp"
database_name_GORG="${database_pass}GORG_v1_NCBInames.dmp"
database_fmi_GORG=" ${database_pass}GORG_v1_NCBI.fmi"
#----------------------------------------------------------------------------------------------

threads=16
start_time=`date +%s`

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

MODE=${MODE_nr}
if   [ $# -gt 1 ]; then
    if   [ ${2} = "GORG" ]; then
        echo "GORG mode"
        database_node=${database_node_GORG}
        database_name=${database_name_GORG}
        database_fmi=${database_fmi_GORG}
        MODE=${MODE_gorg}
    elif [ ${2} = "NrEuk" ]; then
        echo "NR mode" 
    else
        echo "Undefiended mode: ${2}"
        usage
        exit 1   
    fi
else
    echo "NR mode"
fi

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
BASE_FILENAME=${MODE}_${BASE_FILENAME}
echo ${BASE_FILENAME}

OUTPUT_PATH=../taxonomy/${BASE_FILENAME}
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
            -f ${database_fmi} \
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
if [ ! -e ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.summary_domain ]; then
    ${kaiju2krona}   -v -t ${database_node} -n ${database_name}            -o ${OUTPUT_PATH}/${BASE_FILENAME}.krona                    -i ${OUTPUT_FILE}

    #taxono summary (calculate rerative abundances)
    ${kaijuReport}   -v -t ${database_node} -n ${database_name} -r phylum  -o ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.summary_phylum       ${OUTPUT_FILE}
    ${kaijuReport}   -v -t ${database_node} -n ${database_name} -r class   -o ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.summary_class        ${OUTPUT_FILE}
    ${kaijuReport}   -v -t ${database_node} -n ${database_name} -r order   -o ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.summary_order        ${OUTPUT_FILE}
    ${kaijuReport}   -v -t ${database_node} -n ${database_name} -r family  -o ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.summary_family       ${OUTPUT_FILE}
    ${kaijuReport}   -v -t ${database_node} -n ${database_name} -r genus   -o ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.summary_genus        ${OUTPUT_FILE}
    ${kaijuReport}   -v -t ${database_node} -n ${database_name} -r species -o ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.summary_species      ${OUTPUT_FILE}

    #readID-taxon
    ${addTaxonNames} -v -t ${database_node} -n ${database_name}    -p      -o ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.names.out_FULL    -i ${OUTPUT_FILE}
    ${addTaxonNames} -v -t ${database_node} -n ${database_name} -r phylum  -o ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.names.out_phylum  -i ${OUTPUT_FILE}
    ${addTaxonNames} -v -t ${database_node} -n ${database_name} -r class   -o ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.names.out_class   -i ${OUTPUT_FILE}
    ${addTaxonNames} -v -t ${database_node} -n ${database_name} -r order   -o ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.names.out_order   -i ${OUTPUT_FILE}
    ${addTaxonNames} -v -t ${database_node} -n ${database_name} -r family  -o ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.names.out_family  -i ${OUTPUT_FILE}
    ${addTaxonNames} -v -t ${database_node} -n ${database_name} -r genus   -o ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.names.out_genus   -i ${OUTPUT_FILE}
    ${addTaxonNames} -v -t ${database_node} -n ${database_name} -r species -o ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.names.out_species -i ${OUTPUT_FILE}

    #domain
    cat ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.names.out_FULL   |cut -f-2 -d ";" |sed -e "s/cellular organisms; //g" |cut -f-1 -d ";" > ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.names.out_domain
    #cat ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.names.out_domain |cut -f4 |sort |uniq -c |awk '{print "dummy\t" $1 "\t" $2}'           > ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.summary_domain
    cat ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.names.out_domain |cut -f4 |sort |uniq -c |awk '{print "dummy\t0\t" $1 "\t0\t" $2}'     > ${OUTPUT_PATH}/${BASE_FILENAME}_kairep.summary_domain

fi

echo "all done"
./runtime.sh ${start_time}

exit 0
