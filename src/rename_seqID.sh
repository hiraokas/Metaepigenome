#!/bin/sh

function usage() {
    cat <<'EOF'
====================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: 20210209
    history: 20250416
    - this is a script to change sequence ID in the given fasta file.
    - New seqID will be like PREFIX_1, PREFIX_2, PREFIX_3, ... 
Usage:
    this.sh seq.faa/fna prefix
Output:
    ../renameSeqID/XXX.fasta
Exp:
    ./rename_seqID.sh ../gene/12_merge_reduplicate/all164_20211130.faa DSSM
====================================================================================
EOF
    return 0
}   

if [ $# -le 1 ]; then
    echo "Option: $#"
    usage
    exit 1
fi

fastafile=${1}
prefix=${2}

FILENAME=${fastafile##*/}
BASE_FILENAME=${FILENAME%.*}

outputfasta=../renameSeqID/${FILENAME}
outputtable=../renameSeqID/${BASE_FILENAME}.tsv
if [ ! -e ../renameSeqID/ ]; then mkdir ../renameSeqID/; fi

# Rename ID 
echo "Rename seqID... (Output: ${outputfasta}" 
cat ${fastafile} | awk -v prefix=${prefix} '/^>/{print ">" prefix "_" ++i; next}{print}' > ${outputfasta}

# Generate convert table
echo "Make convert table... :${outputtable}"
cat ${fastafile}   | grep ">" | cut -c2- > ${outputtable}.tmp1
cat ${outputfasta} | grep ">" | cut -c2- > ${outputtable}.tmp2
paste ${outputtable}.tmp1 ${outputtable}.tmp2  > ${outputtable}
rm ${outputtable}.tmp{1,2}

echo "All done"
exit
