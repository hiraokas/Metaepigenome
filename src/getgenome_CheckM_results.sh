
function usage() {
    cat <<EOF
======================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created:  20220629
    History:  20230704  # Accept both CheckM1 and CheckM2
    History:  20250108
    - This is a tool for extracting genome sequences from CheckM1/2 results.
    - Get middle- or high-quality genomes (i.e., completeness > 50%, contamination < 10%)
Usage:
    $(basename ${0}) genome_dir checkm_result.tsv
======================================================================================================
EOF
}
usage_exit() { usage; exit 1; }

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

input_genomeDir=${1}
input_qualitytable=${2}

prefix=` basename ${input_qualitytable} | rev | cut -f2-  -d "." | rev | cut -f2- -d "_"  ` 

# detect CheckM1 or CheckM2
FirstWord=`head ${input_qualitytable} -n 1 | cut -f1 `
echo ${FirstWord}
if [ "${FirstWord}" == "Name"  ]; then
    mode="CheckM2"
elif [[ "${FirstWord}" == *CheckM*   ]] ; then
    mode="CheckM1"
fi

output_dir=../checkm_Genome/${mode}_${prefix}
if [ ! -e ${output_dir} ]; then 
    mkdir ${output_dir} -p; 
fi

echo "====================================================================="
echo "INFORMATION"
echo "Dir:         ${prefix}"
echo "Input:       ${input_qualitytable}"
echo "Mode:        ${mode}"
echo "output_dir : ${output_dir}"
echo "====================================================================="

if [ "${mode}" == "CheckM1" ]; then 
    echo " ################### CheckM1 mode ###################"
    count=0
    cat ${input_qualitytable} | grep -v -e "INFO" -e "^--------" -e "Bin Id" | sed -e 's/  */\t/g'| while read line ; do
        count=`echo "$count+1" | bc`
        
        # MC-2_S10_1.29            k__Archaea (UID2)              207         145           103         0    145    0    0    0   0       100.00           0.00               0.00
        #echo $line

        first_chara=`echo "${line}" | cut -c1`
        if [ ${first_chara} == "#" ]; then
            continue
        fi

        #Bin Id                     Marker lineage            # genomes   # markers   # marker sets    0     1     2    3    4   5+   Completeness   Contamination   Strain heterogeneity
        BinID=`         echo "${line}" | cut -f1`
        completeness=`  echo "${line}" | cut -f13`
        contamination=` echo "${line}" | cut -f14`
     
        echo "Completeness: ${completeness}, Contamination: ${contamination}"

        #quality check
        if [ "$(echo "${completeness}  <  50" | bc)" -eq 1 ]; then continue; fi
        if [ "$(echo "${contamination} >= 10" | bc)" -eq 1 ]; then continue; fi

        #file move
        cp  ${1}/${BinID}.{fa,fasta,fna,gz} ${output_dir}/
        echo "copy:  ${output_dir}/${BinID}.XXX"
    done

elif [ "${mode}" == "CheckM2" ]; then 
    echo " ################### CheckM2 mode ###################"
    count=0
    cat ${input_qualitytable} | grep -v  -e "^Name" | while read line ; do
        count=`echo "$count+1" | bc`
        BinID=`         echo "${line}" | cut -f1`
        completeness=`  echo "${line}" | cut -f2`
        contamination=` echo "${line}" | cut -f3`
     
        echo "Completeness: ${completeness}, Contamination: ${contamination}"

        #quality check
        if [ "$(echo "${completeness}  <  50" | bc)" -eq 1 ]; then continue; fi
        if [ "$(echo "${contamination} >= 10" | bc)" -eq 1 ]; then continue; fi

        #file move
        cp ${1}/${BinID}.{fa,fasta,fna,gz} ${output_dir}/
        echo "copy:  ${output_dir}/${BinID}.XXX"
    done
fi

echo "All done."

