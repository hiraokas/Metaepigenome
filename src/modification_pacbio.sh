#!/bin/bash
#$ -m be
#$ -cwd
#$ -pe threads 20

function usage() {
    cat <<'EOF'
==================================================================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: <20170911
    HIstory:  20210202
    History:  20211115
    History:  20220809 (smrtlink v11.0.0)
    History:  20230126 (smrtlink v11.1.0)
    History:  20230427 (smrtlink v12.0.0)
    History:  20230626 (allowing multiple version of smrtlink)
    History:  20240307 (smrtlink v13.0.0)
    History:  20250227 (smrtlink v25.1.0)
    History:  20251223
    - Script for DNA modification detection using mapped PacBio reads.
    - Outline: https://github.com/ben-lerch/BaseMod-3.0
    - Final output: ../modification/xxx_motifs.gff
    - This will take a lot of time in some case (e.g., >10h). Should used max threads (e.g., 39) for batch job submission.
    - Dat analysis flow: mapping.sh -> this
Usage:
    conda activate py38
    this.sh  binned_contigs.fasta  mapped.bam  thread(int)  mode
OPTION:
    mode:
        v6        using SmrtLink v6 (RS2, Sequel) (ipdsummary v2.4)
        v8        using SmrtLink v8 (Sequel) (ipdsummary v2.4.1)
        v10       using SmrtLink v10.2 (Sequel, Sequel II) (ipdsummary v3) (likely not accepted the HiFi kinetics mode...??? Subreads will be OK.)
        v12       using SmrtLink v12.0 (Sequel II)
        v13       using SmrtLink v13.0 (Sequel II)
        v25       using SmrtLink v25.0 (Revio)
        Pylory1   pvalue 0.001,  --minScore 500  --minCoverage 200  (strict)
        Pylory2   TAB
        default   Call only m6A and m4C as a default
        defv10    v10 + default
        defv12    v12 + default
        defv13    v13 + default
        defv25    v25 + default
Tips:
    for f in $(seq 1 150);  do echo ${f}; ./modification_pacbio.sh  ../ViralGenome/CM1_5m.V${f}.fa     ../mapping/CM1_5m.V${f}/pbmm2_CM1_5m.V${f}_CM1_5m_subreads_RE_sorted.bam; done
Install:
    #smrtlink (manual install)    
==================================================================================================================================================================================
EOF
    return 0
}  

if [ $# -lt 4 ]; then
    usage
    exit 1
fi

start_time=`date '+%Y-%m-%d %H:%M:%S.%N'`

CONTIG_FILE=${1}
MAPPED_BAM=${2}
threads=${3}
MODE=${4}

#---------------------------------------------------------------------------------------------------
if [ "${MODE}" = "v8" ] ; then
    MotifMaker=" ${HOME}/software/smrtlink_8.0.0.80529/smrtcmds/bin/motifMaker"
    ipdSummary=" ${HOME}/software/smrtlink_8.0.0.80529/smrtcmds/bin/ipdSummary"
    pbindex="    ${HOME}/software/smrtlink_8.0.0.80529/smrtcmds/bin/pbindex"
elif [ "${MODE}" = "v10" ] || [ ${MODE} == "defv10" ] ; then
    MotifMaker=" ${HOME}/software/smrtlink_10.2.1.143962/smrtcmds/bin/motifMaker"
    ipdSummary=" ${HOME}/software/smrtlink_10.2.1.143962/smrtcmds/bin/ipdSummary"
    pbindex="    ${HOME}/software/smrtlink_10.2.1.143962/smrtcmds/bin/pbindex"
elif [ "${MODE}" = "v12" ] || [ ${MODE} == "defv12" ]  ; then
    MotifMaker=" ${HOME}/software/smrtlink_12.0.0.177059/smrtcmds/bin/motifMaker"
    ipdSummary=" ${HOME}/software/smrtlink_12.0.0.177059/smrtcmds/bin/ipdSummary"
    pbindex="    ${HOME}/software/smrtlink_12.0.0.177059/smrtcmds/bin/pbindex"
elif [ "${MODE}" = "v13" ] || [ ${MODE} == "defv13" ]  ; then
    MotifMaker=" ${HOME}/software/smrtlink_13.0.0.214433/smrtcmds/bin/motifMaker"
    ipdSummary=" ${HOME}/software/smrtlink_13.0.0.214433/smrtcmds/bin/ipdSummary"
    pbindex="    ${HOME}/software/smrtlink_13.0.0.214433/smrtcmds/bin/pbindex"
elif [ "${MODE}" = "v25" ] || [ ${MODE} == "defv25" ]  ; then
    MotifMaker=" ${HOME}/software/smrtlink_25.1.0.257715/smrtcmds/bin/pbmotifmaker"  #name changed
    ipdSummary=" ${HOME}/software/smrtlink_25.1.0.257715/smrtcmds/bin/ipdSummary"
    pbindex="    ${HOME}/software/smrtlink_25.1.0.257715/smrtcmds/bin/pbindex"
else
    echo "Undefined mode: ${MODE}"
    usage
    exit 1
fi

samtools=${HOME}/local/bin/samtools

#---------------------------------------------------------------------------------------------------
#set output filename
FILENAME=${MAPPED_BAM##*/}
BASE_FILENAME=${FILENAME%.*}
EXT=${FILENAME##*.}

output_dir=../modification
output_basemod_gff="  ${output_dir}/${MODE}${BASE_FILENAME}.basemods.gff"
output_basemod_csv="  ${output_dir}/${MODE}${BASE_FILENAME}.basemods.csv"
output_basemod_check="${output_dir}/${MODE}${BASE_FILENAME}.basemods.check"
output_motif_gff="    ${output_dir}/${MODE}${BASE_FILENAME}.motifs.gff"
output_motif_csv="    ${output_dir}/${MODE}${BASE_FILENAME}.motifs.csv"
output_gff_out="      ${output_dir}/${MODE}${BASE_FILENAME}.GFFOut.csv"
output_log_out="      ${output_dir}/${MODE}${BASE_FILENAME}.log"

# log
echo "=================================================================================================="
echo "  modification_pacbio.sh Settings"
echo "=================================================================================================="
echo "Tools:"
echo "    ${MotifMaker}"
echo "    ${ipdSummary}"
echo "    ${pbindex}"
echo "    ${samtools}"
echo "Options:"
echo "    ${MODE}"
echo "Input:"
echo "    ${CONTIG_FILE}"
echo "    ${MAPPED_BAM}"
echo "Output:"
echo "    "${output_basemod_gff}
echo "    "${output_basemod_csv}
echo "    "${output_motif_gff}
echo "    "${output_motif_csv}
echo "    "${output_gff_out}
echo "=================================================================================================="

if [ ! -e ${output_dir} ]; then
    echo "Make new directory: ${output_dir}"
    mkdir ${output_dir} -p
fi

if [ ! -e ${CONTIG_FILE}.fai ]; then
    echo "Make fai file"
    ${samtools} faidx ${CONTIG_FILE}
else
    echo "Skip samtools faidx: already exist: ${CONTIG_FILE}"
fi

if [ ! -e ${MAPPED_BAM}.pbi ]; then
    echo "Make pbi file"
    ${pbindex} ${MAPPED_BAM}
else
    echo "Skip pbindex: already exist: ${MAPPED_BAM}"
fi

#---------------------------------------------------------------------------------------------------
if [ ! -e ${output_basemod_check} ]; then
    echo "Run ipdSummary"

    if  [ "${MODE}" = "default" ]  || [ "${MODE}" = "defv10" ] || [ "${MODE}" = "defv12" ] || [ "${MODE}" = "defv13" ] ; then
        modiication_type="m4C,m6A" 
    else 
        modiication_type="m4C,m6A,m5C_TET" 
    fi

    command="${ipdSummary} ${MAPPED_BAM} --reference ${CONTIG_FILE} --gff ${output_basemod_gff} --csv ${output_basemod_csv} --numWorkers ${threads} --debug --identify ${modiication_type}  --log-file ${output_log_out}" 

    #options
     #--pvalue 0.001 --mapQvThreshold 20 --maxAlignments 1000
    if [ ! -z ${MODE} ] && [ "${MODE}" = "V1" ]; then
        command="${command} --pvalue 0.01   "  # --m5Cgff ${output_basemod_gff}.m5C.gff
    elif [ ! -z ${MODE} ] && [ "${MODE}" = "Pylory1" ]; then
        command="${command} --pvalue 0.001 --minCoverage 200"
    fi

    echo ${command}
    ${command}
    if [ -e ${output_basemod_csv}  ]; then
        touch ${output_basemod_check}
    fi
else
    echo "Skip ipdSummary : already exist: ${output_basemod_check}"
fi

#---------------------------------------------------------------------------------------------------
if [ ! -e ${output_motif_csv} ]; then
    echo "Run motifMaker find"
    if [ ! -z ${MODE} ] && [ "${MODE}" = "V1"      ]; then
        ##java -jar -Xmx100G ${MotifMaker} find -f ${CONTIG_FILE} -g ${output_basemod_gff} -o ${output_motif_csv} --minScore 20
        ${MotifMaker} find -f ${CONTIG_FILE} -g ${output_basemod_gff} -o ${output_motif_csv} -j ${threads} --minScore 20
    elif [ ! -z ${MODE} ] && [ "${MODE}" = "Pylory1" ]; then
        ${MotifMaker} find -f ${CONTIG_FILE} -g ${output_basemod_gff} -o ${output_motif_csv} -j ${threads} --minScore 500
    elif [ "${MODE}" = "v8" ] || [ "${MODE}" = "v10" ] || [ "${MODE}" = "defv10" ] ; then   #no threads option for old versions
        ${MotifMaker} find -f ${CONTIG_FILE} -g ${output_basemod_gff} -o ${output_motif_csv}  
    elif [ "${MODE}" = "v25" ] || [ "${MODE}" = "defv25" ] ; then   
        ${MotifMaker} find    ${CONTIG_FILE}    ${output_basemod_gff}    ${output_motif_csv} -j ${threads}  
    else
        ${MotifMaker} find -f ${CONTIG_FILE} -g ${output_basemod_gff} -o ${output_motif_csv} -j ${threads} 
    fi
else
    echo "Skip MotifMaker find: already exist: ${output_motif_csv}"
fi

#---------------------------------------------------------------------------------------------------
if [ ! -e ${output_motif_gff} ]; then
    echo "Run motifMaker reprocess"
    if [ "${MODE}" = "v25" ] || [ "${MODE}" = "defv25" ] ; then   
        ${MotifMaker} reprocess    ${CONTIG_FILE}    ${output_basemod_gff}    ${output_motif_csv}    ${output_motif_gff}  -j ${threads}  
    else
        ${MotifMaker} reprocess -f ${CONTIG_FILE} -g ${output_basemod_gff} -m ${output_motif_csv} -o ${output_motif_gff} # -j ${threads} <- not supported currently
    fi
else
    echo "Skip motifMaker reprocess: already exist: ${output_motif_gff}"
fi

echo "All done."

#---------------------------------------------------------------------------------------------------
end_time=`date '+%Y-%m-%d %H:%M:%S.%N'`
BEGIN_UT="$(date -d ${start_time} +%s)"
END_UT="$(date -d ${end_time} +%s)"
total_time="$(((END_UT - BEGIN_UT) / (60 * 60 )))"
echo "Start: ${start_time}"
echo "End:   ${end_time}"
echo "Total run time: ${total_time}h"

exit 0

