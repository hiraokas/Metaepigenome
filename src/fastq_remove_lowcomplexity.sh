#!/bin/sh
#$ -m be
#$ -cwd
#$ -pe threads 1

function usage() {
    cat <<'EOF'
==================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20180521
    History: 20210903
    History: 20211207
    History: 20220308 (change to use prinseq++)
    History: 20220416 (Change to input/output foemat as .gz)
    History: 20251226
    - Remove low complexity reads, and <100bp length using prinseq++
Require:
    perl modules
    prinseq++
Usage:
    conda activate py38                 # (for perl modules)
    this.sh fastq  single [threads=10]  # (single reads)
    this.sh fastq1 paired [threads=10]  # (paired-end/mait-pair reads)
Output:
    ../data/15_nocomplex_upper100/
Exp:
    # paired-end mode
    for f in ../data/14_nophiX/*_1.fastq.gz;  do ./fastq_remove_lowcomplexity.sh ${f} paired; done
    for f in ../data/14_nophiX/*.1.fastq;     do ./qsub_da.sh 10 ./fastq_remove_lowcomplexity.sh ${f} paired; done
    for f in ../data/14_nophiX/*.1.fastq;     do bash -c "nohup  ./fastq_remove_lowcomplexity.sh ${f} paired &"; done

    # single-end mode
    for f in ../data/14_nophiX/*.extendedFrags.fastq;  do ./fastq_remove_lowcomplexity.sh ${f} single; done
    nohup bash -c 'for f in ../data/14_nophiX/*.fastq; do ./fastq_remove_lowcomplexity.sh ${f} single; done' &
==================================================================================================================
EOF
    return 0
}

#------------------------------------------------------------------
outputdir="../data/15_nocomplex_upper100/"
prinseq="  ${HOME}/software/prinseq-lite-0.20.4/prinseq-lite.pl"
prinseqpp="${HOME}/software/prinseq++"
threads=10
#------------------------------------------------------------------

if [ $# -lt 2 ]; then
    echo "Error: Please set fastq file"
    usage
    exit 1
fi

#source ${HOME}/miniconda3/etc/profile.d/conda.sh
#conda activate py38

fileName_P1=${1##*/}       #hogehoge(_1/.1/.extendedFrags).fastq(.gz)
fileName_P1=`echo ${fileName_P1} | sed -e "s/.gz$//g" | sed  "s|\.extendedFrags||"`  #hogehoge(_1/.1).fastq
Prefix=${fileName_P1%.*}   #hogehoge(_1/.1)

mode=${2}
echo "mode: ${mode}"

if [ $# -gt 2 ]; then
    threads=${3}
    echo "Threads: ${threads}"
fi

if [ ${mode} = "paired" ]; then
    filepath_P1=${1}
    #filepath_P2=`echo ${1}| sed  "s/_1.fastq/_2.fastq/g" | sed  "s/.1.fastq/.2.fastq/g" | sed "s/_R1.fq/_R2.fq/g"`  #St1150_S00_M_1.fastq -> St1150_S00_M_2.fastq , capture_ON4-50m_R1.fq -> capture_ON4-50m_R2.fq
     filepath_P2=`echo ${1}| sed -e "s/_1.fastq/_2.fastq/g" -e "s/.1.fastq/.2.fastq/g" -e "s/_R1.fq/_R2.fq/g"`  #St1150_S00_M_1.fastq -> St1150_S00_M_2.fastq , capture_ON4-50m_R1.fq -> capture_ON4-50m_R2.fq
    #Prefix=`     echo ${Prefix}| sed  "s|\.1\.||"| sed  "s|\.2\.||" | sed  "s|_R1||" | sed  "s|_R2||" | sed  "s/_1//g"| sed  "s/_2//g" `  #remove .1, _1, _R1
     Prefix=`echo ${Prefix}| sed -e "s|\.1\.||" -e "s|\.2\.||" -e "s|_R1||" -e "s|_R2||" -e "s/_1//g" -e "s/_2//g" `  #remove .1, _1, _R1
fi

if [ ! -e ${outputdir} ]; then
    echo "make output dir: ${outputdir}"
    mkdir ${outputdir}
fi

if   [ ${mode} = "single" ]; then
    output_filename=${Prefix}.fastq
elif  [ ${mode} = "paired" ]; then
    output_filename=${Prefix}_1.fastq
fi

if [ -e ${outputdir}/${Prefix}.check ] && [ ! -e ${outputdir}/${Prefix}.NowRanning  ] ; then
    echo "File already exist. Skip: ${Prefix}"
    exit
fi

touch ${outputdir}/${Prefix}.NowRanning

if   [ ${mode} = "single" ]; then
    echo "---remove low complexity: ${filepath_P1}"
    
    # legacy prinseq
    # perl ${prinseq} -lc_method dust -lc_threshold 7 -min_len 100 -fastq ${filepath_P1} \
    #     -out_good ${outputdir}/${Prefix} -out_bad null
    
    # prinseq++
    echo ${prinseqpp} -min_len 100 -fastq ${filepath_P1} -threads ${threads} -out_gz        -out_good ${outputdir}/${Prefix}.fastq.gz         -out_bad    /dev/null          -out_single /dev/null  
         ${prinseqpp} -min_len 100 -fastq ${filepath_P1} -threads ${threads} -out_gz        -out_good ${outputdir}/${Prefix}.fastq.gz         -out_bad    /dev/null          -out_single /dev/null  

    mv ${outputdir}/${Prefix}.NowRanning ${outputdir}/${Prefix}.check
    echo "Output: ${outputdir}/${output_filename}"

elif [ ${mode} = "paired" ]; then
    echo "---remove low complexity: ${filepath_P1} ${filepath_P2}"
    
    # legacy prinseq
    # perl ${prinseq} -lc_method dust -lc_threshold 7 -min_len 100 -fastq ${filepath_P1} -fastq2 ${filepath_P2}  \
    #     -out_good ${outputdir}/${Prefix} -out_bad null

    # prinseq++
    echo ${prinseqpp} -min_len 100 -fastq ${filepath_P1} -fastq2 ${filepath_P2}  -threads ${threads} -out_gz    -out_good ${outputdir}/${Prefix}_1.fastq.gz  -out_good2 ${outputdir}/${Prefix}_2.fastq.gz         -out_bad    /dev/null -out_bad2    /dev/null         -out_single /dev/null -out_single2 /dev/null
         ${prinseqpp} -min_len 100 -fastq ${filepath_P1} -fastq2 ${filepath_P2}  -threads ${threads} -out_gz    -out_good ${outputdir}/${Prefix}_1.fastq.gz  -out_good2 ${outputdir}/${Prefix}_2.fastq.gz         -out_bad    /dev/null -out_bad2    /dev/null         -out_single /dev/null -out_single2 /dev/null
    
    mv ${outputdir}/${Prefix}.NowRanning ${outputdir}/${Prefix}.check
    echo "Output: ${outputdir}/${output_filename}"
else
    echo "Error: illigal mode: ${mode}"
    exit
fi

echo "@@@Done."
