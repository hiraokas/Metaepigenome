#!/bin/bash
#$ -m be
#$ -cwd
#$ -pe threads 6

function usage() {
    cat <<EOF
========================================================================================================================================
Description:
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created:  <2019
    History: 20230502 (REBASE 20220530)
    History: 20230503 (REBASE 20230503)
    History: 20231007 (dbCAN v12)
    History: 20240301 (REBASE 20240301)
    History: 20241007 (dbCAN v13)
    History: 20250202
    - This script is for Blast search and annotation against protein sequence database.
Usage:
    $(basename ${0}) [command] [<options>]
Required:
    -t  database type 
    		[sprot, nog, REBASE, Pfam, dbCAN, KEGG, NR...]
    		[PET, PET_PETase, PET_Cbotu, lasso_cyc, NCyc]
    -d  specific_database (NOT WORK)
    -i  fasta file (.fna or .faa(hmmer) )
    -b  blast output file
    -s  search tool 
            [blast, rapsearch, ghostz, paladin, mmseq2, diamond, 
             diamond-c50(alignment length cover >50%), diamond-sensitive(not evaluated)] (similarity search)
            [hmmer, hhblits(not work)] (HMM search)
Options:
    -T  Threads (=6)
    -h  Print this
    -H  Print hint for making database
TIPS:
    ./blast_annotation.sh -t nog -i ../genecall/B01.fna
========================================================================================================================================
EOF
}

function usage2() {
    cat <<EOF
========================================================================================================================================
TIPS: Making databases 
========================================================================================================================================
Database:
    nr:
        #ncbi-blast-dbs nr
        #wget http://ftp.ncbi.nlm.nih.gov/blast/db/FASTA/nr.gz
        aria2c -x5 http://ftp.ncbi.nlm.nih.gov/blast/db/FASTA/nr.gz
    swiss prot:
        cat uniprot_sprot_2020_04.fasta | grep ">" > uniprot_sprot_2020_04.fasta_seqname
    KEGG:
        stored in DA system: /work/dbank/disk4/data/kegg
    REBASE:
        #files must be downloaded via FTP, not web browser
        #http://rebase.neb.com/rebase/rebase.seqs.html
        cat All_REBASE_Gold_Standards_Protein_20240301.txt | sed -e '/^>/!s/ //g'  | sed '/^$/d'  > All_REBASE_Gold_Standards_Protein_20240301.faa
        diamond makedb --in All_REBASE_Gold_Standards_Protein_20240301.faa -d All_REBASE_Gold_Standards_Protein_20240301 --threads 4
Tools:
    blast:
        ~/software/ncbi-blast-2.3.0+/bin/makeblastdb -dbtype prot -in XXX.fasta -hash_index -parse_seqids -gi_mask
        makeblastdb -dbtype prot -in XXX.fasta -parse_seqids -gi_mask
    diamond:
        diamond makedb --in reference.fasta -d reference --threads 4
        # this will produce "reference.dmnd" file
    mmseq2:
        mmseqs createdb examples/DB.fasta targetDB
        mmseqs createindex targetDB tmp --threads 20
    hmmer:
        hmmpress dbCAN-HMMdb-V9.txt
    ghostz:
        nohup ${HOME}/software/ghostz-1.0.2/ghostz db -i eggnog4.proteins.all.fa -o eggnog4.proteins.all.fa_ghostz &
    hhsuite:
        database_name=dbcan07202017
        ~/workspace/software/hh-suite/build/bin/ffindex_from_fasta -s dbcan07202017_fas.ff{data,index} CAZyDB.07202017.fa
        ~/workspace/software/hh-suite/build/bin/hhblits -i dbcan07202017_fas -d dbcan07202017 -oa3m dbcan07202017_a3m_wo_ss -n 2 -cpu 1 -v 0
========================================================================================================================================
EOF
}

usage_exit() {
	usage
	exit 1
}

start_time=`date +%s`

#1
sprot_id=1
sprot_name="sprot"
sprot_database="        ${HOME}/database/UniProt/uniprot_sprot_2019_10.fasta"
sprot_database_rap="    ${HOME}/database/UniProt/uniprot_sprot_2019_10.fasta_rapdb"
sprot_database_ghostz=" ${HOME}/database/UniProt/uniprot_sprot_2019_10.fasta_ghostz"
sprot_database_paladin="${HOME}/database/UniProt/uniprot_sprot_2019_10.fasta.gz"
sprot_database_mmseq2=" ${HOME}/database/UniProt/uniprot_sprot_2020_04.fasta.mmseq2"
sprot_annotation="      ${HOME}/database/UniProt/uniprot_sprot_2020_04.fasta_seqname"

#2
NOG_id=2
NOG_name="eggNOGv5"
NOG_database="        ${HOME}/database/eggNOG5/eggnog4.proteins.core_periphery.fa"
NOG_database_rap="    ${HOME}/database/eggNOG5/eggnog4.proteins.all.fa_rapdb"
NOG_database_ghostz=" ${HOME}/database/eggNOG5/e5.proteomes.faa_ghostz"
NOG_database_diamond="${HOME}/database/eggNOG5/e5.proteomes.dmnd"
NOG_database_paladin="${HOME}/database/eggNOG5/eggnog4.proteins.core_periphery.fa.gz"
NOG_members="         ${HOME}/database/eggNOG5/e5.taxid_info.tsv"
NOG_annotation="      ${HOME}/database/eggNOG5/e5.og_annotations.tsv"

#3
REBASE_id=3
REBASE_name="REBASEv20240301"
REBASE_database="        ${HOME}/database/REBASE/All_REBASE_Gold_Standards_Protein_20240301.faa"
REBASE_database_diamond="${HOME}/database/REBASE/All_REBASE_Gold_Standards_Protein_20240301.dmnd"  

#4
Pfam_id=4
Pfam_name="Pfamv32"
Pfam_database="        ${HOME}/database/Pfam_32.0/Pfam-A.fasta"
#Pfam_database_hmm="    ${HOME}/database/PfamA_33.1/Pfam-A.hmm"
#Pfam_database_hmm="    ${HOME}/database/Pfam_35.0/Pfam-A.hmm.gz"
#Pfam_database_hhsuite="${HOME}/database/Pfam_32.0/pfam"
Pfam_annotation="      ${HOME}/database/Pfam_33.1/Pfam-A.clans.tsv"

#5
dbCAN_id=5
dbCAN_name="dbCANv13"
dbCAN_database_hmm="    ${HOME}/database/dbCAN/dbCAN-HMMdb-V13.txt"
dbCAN_annotation=${Pfam_annotation}

#6
KEGG_id=6
KEGG_name="KEGG"
KEGG_database="        ${HOME}/database/kegg/kegg_20211205/prokaryotes.pep"
KEGG_database_ghostz=" ${HOME}/database/kegg/kegg_20211205/prokaryotes.pep_ghostz"
KEGG_database_diamond="${HOME}/database/kegg/kegg_20211205/prokaryotes.pep.dmnd"
KEGG_database_mmseq2=" ${HOME}/database/kegg/kegg_20211205/prokaryotes.pep_mmseq2"

NR_id=7
NR_name="NRv20210927"
NR_database="          ${HOME}/database/nr/nr_20210927/nr"
NR_database_diamond="  ${HOME}/database/nr/nr_20210927/nr.dmnd"

#10
PET_id=10
PET_name="PET"
PET_database="${HOME}/workspace/_PETase/reference_PETase_sequence/reference_PETase2.faa"

PET1_id=11
PET1_name="PET_PETase"
PET1_database="${HOME}/workspace/_PETase/reference_PETase_sequence/reference_Cut.faa"

PET2_id=12
PET2_name="PET_Cbotu"
PET2_database="${HOME}/workspace/_PETase/reference_PETase_sequence/reference_Cbotu.faa"


lasso_cyc_id=20
lasso_cyc_name="lasso_cyc"
lasso_cyc_database="${HOME}/workspace/_lasso/lasso_sequence/uniprot-Lasso+peptide+isopeptide+bond-forming+cyclase.fasta"

NCyc_id=30
NCyc_name="NCyc"
NCyc_database="        ${HOME}/database/NCyc-master/data/NCyc_100.faa"
NCyc_database_ghostz=" ${HOME}/database/NCyc-master/data/NCyc_100.faa_ghostz"
NCyc_database_diamond="${HOME}/database/NCyc-master/data/NCyc_100.dmnd"

#tool
#blast=""
ghostz="    ${HOME}/workspace/software/ghostz-1.0.2/ghostz"
mmseq2="    ${HOME}/workspace/software/MMseqs2/build/src/mmseqs"
hmmscan="   ${HOME}/software/hmmer-3.3.2/src/hmmsearch"
hhblitsDIR="${HOME}/workspace/software/hh-suite"
hhblits="   ${hhblitsDIR}/build/bin/hhblits"
diamond="   ${HOME}/software/diamond"

rapsearch="../module/RAPSearch2-master/bin/rapsearch"
paladin="  ../../software/paladin/paladin"


#init
OutputDir="../blast"
QUERY_FILE=""
THREADS=6
SEARCHTOOL=""
database_type=""

##==============================================
#http://qiita.com/b4b4r07/items/dcd6be0bb9c9185475bb
while getopts t:i:b:hT:s:H OPT
do
	case $OPT in
		t)	database_type=$OPTARG
			;;
		i)	FLAG_A=0
			QUERY_FILE=$OPTARG
			string_filename=${QUERY_FILE##*/}
			string_filename_without_extension=${string_filename%.*}
			file_basename=${string_filename_without_extension}
            ;;
		b)	FLAG_A=1
			QUERY_FILE=$OPTARG
			string_filename=${QUERY_FILE##*/}
			string_filename_without_extension=${string_filename%.*}
			file_basename=`echo ${string_filename_without_extension%_*}|cut -d "_" -f2-`  #split "blast_" and "_sprot"
			;;
		h)	usage_exit
			exit 0
			;;
		H)  usage2
            exit 1
            ;;
        s)	SEARCHTOOL=$OPTARG
			echo ${SEARCHTOOL} 
			;;
		T)	THREADS=$OPTARG
			;;
        \?)	usage_exit
			;;
	esac
done

if [ -z ${QUERY_FILE} ]; then
	echo "No input filename."
	usage_exit
	exit 0
fi

if [ -z ${database_type} ]; then
	echo "No database type name."
	usage_exit
	exit 0
fi

if [ -z ${SEARCHTOOL} ]; then
	echo "No input sarech tool."
	usage_exit
	exit 0
fi

#echo ${database_type}
if [ "${database_type}" = "sprot" ] ; then 	db_name=${sprot_name}; 	db_type=${sprot_id}
	if   [ "${SEARCHTOOL}" = "blast"     ] ; then	database=${sprot_database}
	elif [ "${SEARCHTOOL}" = "rapsearch" ] ; then	database=${sprot_database_rap}
	elif [ "${SEARCHTOOL}" = "ghostz"    ] ; then	database=${sprot_database_ghostz}
	elif [ "${SEARCHTOOL}" = "paladin"   ] ; then	database=${sprot_database_paladin}
    elif [ "${SEARCHTOOL}" = "mmseq2"    ] ; then   database=${sprot_database_mmseq2}
	else
		echo "Illegal search tool name"
		usage_exit
		exit 1
	fi
elif [ "${database_type}" = "nog"  ] ; then	 db_name=${NOG_name}; 	db_type=${NOG_id}
	if   [ "${SEARCHTOOL}" = "blast"     ] ;   then	database=${NOG_database}
	elif [ "${SEARCHTOOL}" = "rapsearch" ] ;   then	database=${NOG_database_rap}
	elif [ "${SEARCHTOOL}" = "ghostz"    ] ;   then	database=${NOG_database_ghostz}
    elif [ "${SEARCHTOOL}" = "diamond"   ] ;   then database=${NOG_database_diamond}
    elif [ "${SEARCHTOOL}" = "diamond-c50" ] ; then database=${NOG_database_diamond}
	elif [ "${SEARCHTOOL}" = "paladin"   ] ;   then	database=${NOG_database_paladin}
	else
		echo "Illegal search tool name"
		usage_exit
		exit 1
	fi
elif [ "${database_type}" = "REBASE"   ] ; then  db_name=${REBASE_name};     db_type=${REBASE_id}
    if [   "${SEARCHTOOL}" = "blast"   ] ; then  database=${REBASE_database}
    elif [ "${SEARCHTOOL}" = "diamond" ] ; then  database=${REBASE_database_diamond}
    else
        echo "Illegal search tool name"
        usage_exit
        exit 1
    fi
elif [ "${database_type}" = "Pfam"     ] ; then  db_name=${Pfam_name};    db_type=${Pfam_id}
    if   [ "${SEARCHTOOL}" = "ghostz"  ]; then  database=${Pfam_database}
    elif [ "${SEARCHTOOL}" = "hmmer"   ]; then  database=${Pfam_database_hmm}
    elif [ "${SEARCHTOOL}" = "hhblits" ]; then  database=${Pfam_database_hhsuite}
    else
        echo "Illegal search tool name"
        usage_exit
        exit 1
    fi
elif [ "${database_type}" = "dbCAN"  ]  ; then  db_name=${dbCAN_name};     db_type=${dbCAN_id}
    if [ "${SEARCHTOOL}" = "hmmer" ]    ; then       database=${dbCAN_database_hmm}
    elif [ "${SEARCHTOOL}" = "hhblits" ]; then       database=${dbCAN_database_hhsuite}
    else
        echo "Illegal search tool name"
        usage_exit
        exit 1
    fi
elif [ "${database_type}" = "KEGG"  ] ;    then  db_name=${KEGG_name};    db_type=${KEGG_id}
    if   [ "${SEARCHTOOL}" = "blast"   ] ; then    database=${KEGG_database}
    elif [ "${SEARCHTOOL}" = "ghostz"  ] ; then    database=${KEGG_database_ghostz}
    elif [ "${SEARCHTOOL}" = "diamond" ] ; then    database=${KEGG_database_diamond}
    elif [ "${SEARCHTOOL}" = "diamond-c50" ]; then database=${KEGG_database_diamond}
    elif [ "${SEARCHTOOL}" = "mmseq2"  ] ; then    database=${KEGG_database_mmseq2}
    else
        echo "Illegal search tool name"
        usage_exit
        exit 1
    fi
elif [ "${database_type}" = "NR"  ] ; then  db_name=${NR_name};    db_type=${NR_id}
    if   [ "${SEARCHTOOL}" = "diamond"  ] ; then    database=${NR_database_diamond}
    elif [ "${SEARCHTOOL}" = "diamond-c50" ]; then  database=${NR_database_diamond}
    else
        echo "Illegal search tool name"
        usage_exit
        exit 1
    fi
elif [ "${database_type}" = "PET"  ] ; then         db_name=${PET_name};          db_type=${PET_id}
    if [ "${SEARCHTOOL}"  = "blast" ] ; then        database=${PET_database}
    fi
elif [ "${database_type}" = "PET_PETase"  ] ; then  db_name=${PET1_name};         db_type=${PET1_id}
    if [ "${SEARCHTOOL}"  = "blast" ] ; then        database=${PET1_database}
    fi
elif [ "${database_type}" = "PET_Cbotu"  ] ; then   db_name=${PET2_name};         db_type=${PET2_id}
    if [ "${SEARCHTOOL}"  = "blast" ] ; then        database=${PET2_database}
    fi
elif [ "${database_type}" = "lasso_cyc"  ] ; then   db_name=${lasso_cyc_name};    db_type=${lasso_cyc_id}
    if [ "${SEARCHTOOL}"  = "blast" ] ; then        database=${lasso_cyc_database}
    fi
elif [ "${database_type}"  = "NCyc"  ]  ; then      db_name=${NCyc_name};         db_type=${NCyc_id}
    if   [ "${SEARCHTOOL}" = "blast" ]  ; then      database=${NCyc_database}
    elif [ "${SEARCHTOOL}" = "ghostz" ] ; then      database=${NCyc_database_ghostz}
    elif [ "${SEARCHTOOL}" = "diamond" ]; then      database=${NCyc_database_diamond}
    elif [ "${SEARCHTOOL}" = "diamond-c50" ]; then  database=${NCyc_database_diamond}
    fi
else
	echo "Illegal database name"
	usage_exit
	exit 1
fi

echo "=============================INFORMATION==============================="
echo "database      : ${db_name}"
echo "database path : ${database}"
echo "tool          : ${SEARCHTOOL}"
echo "======================================================================="


#check database existence
#pending


output_blast_base=${OutputDir}/${SEARCHTOOL}_${file_basename}_${db_name}
output_blast_set=${output_blast_base}.tsv
output_blast_real=${output_blast_set}
output_blast_run=${output_blast_set}.NowRunning
output_annotation=${OutputDir}/${SEARCHTOOL}Annotation_${file_basename}_${db_name}.tsv

if [ ! -e ${OutputDir} ]; then
    mkdir ${OutputDir}
fi

#check query file format
EXT=${QUERY_FILE##*.}  # query file format
if [ ${EXT} = "fa" ] || [ ${EXT} = "fna" ] || [ ${EXT} = "fasta" ]; then
    QUERY_FILE_TYPE="DNA"
else
    QUERY_FILE_TYPE="PROTEIN"
fi

#search
if [ ${FLAG_A} = 0 ] ; then
	if [ "${SEARCHTOOL}" = "blast" ] ; then
		echo "blast search..."
        #check query file format
        if [ ${QUERY_FILE_TYPE} = "DNA" ]; then
            blast="~/local/bin/blastx -query_gencode 11"
        else
            blast="~/local/bin/blastp"
        fi

        touch ${output_blast_run}
		command="${blast} -db ${database} -query ${QUERY_FILE} -outfmt 6 -max_target_seqs 1 -evalue 1e-5 -num_threads ${THREADS}  > ${output_blast_set}"  #-num_alignments 1 
	    echo ${command}
        eval ${command}
        rm  ${output_blast_run}

    elif [ "${SEARCHTOOL}" = "rapsearch" ] ; then
		echo "rapsearch search..."
		command="${rapsearch} -q ${QUERY_FILE} -d ${database} -o ${output_blast_set} -z ${THREADS} -v 1 -b 0 -e -5/0.00001"
	    echo ${command}
        eval ${command}

    elif [ "${SEARCHTOOL}" = "ghostz" ] ; then
		echo "ghostz search..."

        #check query file format
        if [ ${QUERY_FILE_TYPE} = "DNA" ]; then
            ghostz_query_type="d"
        else
            ghostz_query_type="p"
        fi

        touch ${output_blast_run}
		command="${ghostz} aln -i ${QUERY_FILE} -d ${database} -o ${output_blast_set} -a ${THREADS} -b 1 -v 1 -q ${ghostz_query_type}"
    	echo ${command}
        eval ${command}
        rm ${output_blast_run}

    elif [ "${SEARCHTOOL}" = "paladin" ] ; then
		echo "paladin search..."
        if [ "${database_type}" = "sprot" ] ; then
    		command="${paladin} align -t ${THREADS} -o ${output_blast_set} ${database} ${QUERY_FILE}"
        elif [ "${database_type}" = "nog" ] ; then
            command="${paladin} align -t ${THREADS} ${database} ${QUERY_FILE} >${output_blast_set}"
        fi
        echo ${command}
        eval ${command}

    elif [ "${SEARCHTOOL}" = "mmseq2" ] ; then
        echo "mmseq2 search..."
        if [ ! -e ${QUERY_FILE}.mmseq2 ]; then
            ${mmseq2} createdb ${QUERY_FILE} ${QUERY_FILE}.mmseq2
        fi 
        ${mmseq2} search      ${QUERY_FILE}.mmseq2 ${database} ${output_blast_base}.preconv ../blast/tmp --threads ${THREADS} 
        ${mmseq2} convertalis ${QUERY_FILE}.mmseq2 ${database} ${output_blast_base}.preconv ${output_blast_set}

    elif [ "${SEARCHTOOL}" = "hmmer" ] ; then
        touch ${output_blast_base}.NowRunning
        #command="hmmscan --tblout ${output_blast_set} -o ${output_blast_base}.out --cpu ${THREADS} -E 1e-5 ${database} ${QUERY_FILE}"
        #command="hmmscan -o ${output_blast_set}.out --tblout ${output_blast_set} --domtblout ${output_blast_base}.domtblout --cpu ${THREADS} -E 1e-3 --noali ${database} ${QUERY_FILE}"
        #command="hmmscan --tblout ${output_blast_set} --domtblout ${output_blast_base}.domtblout --cpu ${THREADS} -E 1e-3 --noali ${database} ${QUERY_FILE}"
        #command="${hmmscan} --tblout ${output_blast_set} --domtblout ${output_blast_base}.domtblout --cpu ${THREADS} --domE 1e-3 --noali ${database} ${QUERY_FILE}"
        
        #command="${hmmscan} -o ${output_blast_set}  --domtblout ${output_blast_base}.domtblout --cpu ${THREADS} --domE 1e-3 --noali ${database} ${QUERY_FILE}"
        command="${hmmscan} --domtblout ${output_blast_base}.domtblout --cpu ${THREADS} --domE 1e-3 --noali ${database} ${QUERY_FILE} > /dev/null 2>&1"
        echo ${command}
        eval ${command}
        rm ${output_blast_base}.NowRunning

    elif [ "${SEARCHTOOL}" = "hhblits" ] ; then
        #split multi fasta file into single ones
        ${hhblitsDIR}/scripts/splitfasta.pl ${QUERY_FILE}

        ${hhblits} -i ${QUERY_FILE} -oa3m query.a3m -o ${output_blast_set} -blasttab ${output_blast_base}.domtblout \
                 --cpu ${THREADS} -e 0.001 -d ${database}

    elif [ "${SEARCHTOOL}" = "diamond" ] || [ "${SEARCHTOOL}" = "diamond-sensitive" ] || [ "${SEARCHTOOL}" = "diamond-c50" ] ; then
        #check query file format
        if [ ${QUERY_FILE_TYPE} = "DNA" ]; then
            blast="blastx -query_gencode 11"
        else
            blast="blastp"
        fi

        option=""
        if [ "${SEARCHTOOL}" = "diamond-sensitive" ]; then
            option="--ultra-sensitive"
        fi
        if [ "${SEARCHTOOL}" = "diamond-c50" ]; then
            option="--subject-cover 50 --query-cover 50"
        fi

        touch ${output_blast_run}
        command="${diamond} ${blast} --db ${database} --query ${QUERY_FILE} --outfmt 6 --max-target-seqs 1  --evalue 1e-5 --threads ${THREADS} ${option}  > ${output_blast_set}"
        echo ${command};  eval ${command}
        rm  ${output_blast_run}

    fi
	
else
	echo "skiped blast search."
	output_blast_set=${QUERY_FILE}
	output_blast_real=${QUERY_FILE}
fi


echo "======================================================================="
echo "annotation..."


if [ "${SEARCHTOOL}" = "blast" ] || [ "${SEARCHTOOL}" = "rapsearch" ] ; then

	break  #NO ANNOTAION

    echo ${db_type}
    if [ ! "${db_type}" = "${sprot_id}" ] && [ ! "${db_type}" = "${NOG_id}" ] ; then
        echo "skip (further function will not be annotated)"
        echo ""
        exit
    fi

    if [  ${db_type} = ${KEGG_id} ] ; then
    	exit
    fi

    echo -n > ${output_annotation}
    echo "output: ${output_annotation}"
    echo "${SEARCHTOOL} mode"

	cat ${output_blast_real}| while read line
	do
		#convert space into tab
		#line=`cat ${line}| sed "s/[\t ]\+/\t/g"|`
		
		#echo ${line}
		gene_id=`echo ${line}| cut -d " " -f1`
		ref_id=` echo ${line}| cut -d " " -f2`
		if [ ${gene_id} = "#" ] ; then  #comments for rapsearch output
			continue
		fi
		
		#e-value cutoff (e.g., <10^5)
		#if [ "${SEARCHTOOL}" = "rapsearch" ] ; then
		#	bit_score=`echo ${line}| cut -d " " -f11`
		#	echo ${bit_score}
		#	if [ "$(echo "${bit_score} <= -5.0" | bc)" -eq 0 ] ; then #>10^-5
		#		echo "asfa"
		#		continue
		#	fi
		#fi
		
		#sprot
		if [ ${db_type} = ${sprot_id} ] ; then

			name=`cat ${sprot_annotation} | grep "${ref_id}" -m 1 |cut -f2- -d" "|cut -f1 -d "="|head -c-4`
			output_line="${gene_id}""	""${ref_id}""	""${name}"
		
		#NOG
		elif [ ${db_type} = ${NOG_id} ] ; then
			nogid=`cat ${NOG_members} | grep "${ref_id}" -m 1 | cut -f2`
			if [ -n "${nogid}" ] ; then
				function_and_categoly=`cat ${NOG_annotation}| grep "${nogid}	" -m 1 | cut -f5-`  #ƒ^ƒu‚Í‘åŽ–
				function=`echo "${function_and_categoly}" | cut -f2`
				category=`echo "${function_and_categoly}" | cut -f1`
			else
				function=""
				category=""
			fi
			output_line="${gene_id}""	""${ref_id}""	""${function}""	""${category}"
        
		else
			echo "Unknown error"
			exit 1
		fi	
		
		echo -e "${output_line}"
		echo -e "${output_line}">>${output_annotation}
	done

elif [ "${SEARCHTOOL}" = "ghostz" ] ; then
	echo "${SEARCHTOOL} mode"

	#NOG==================
	if [ ${db_type} = ${sprot_id} ] ; then 
        echo "blast_annotation_uniprot.py"
		python3 blast_annotation_uniprot.py ${output_blast_set}
    elif [ ${db_type} = ${NOG_id} ] ; then 
        echo "blast_annotation_nog.py"
        python3 blast_annotation_nog.py     ${output_blast_set}
    elif [ ${db_type} = ${KEGG_id} ] ; then 
        echo "blast_annotation_kegg.py"
        python3 blast_annotation_kegg.py    ${output_blast_set}
	else

        echo -n > ${output_annotation}
        echo "output: ${output_annotation}"

		cat ${output_blast_set}| while read line
		do
			#echo ${line}
			gene_id_line=`echo "${line}" | cut -f1`  #M00587:17:000000000-AK158:1:1101:14247:1241_1 # 2 # 469 # -1 # ID=33_1;partial=11;start_type=Edge;rbs_motif=None;rbs_spacer=None;gc_cont=0.235
			ref_id_line=` echo "${line}" | cut -f2`  #sp|Q1RI08|PRIA_RICBR Primosomal protein N' OS=Rickettsia bellii (strain RML369-C) GN=priA PE=3 SV=1
			e_value=`     echo "${line}" | cut -f11 |sed "s/e\([0-9]*\)/*10^\1/g"`  #4.10684e-06 -> 4.10684e^-06
			bit_score=`   echo "${line}" | cut -f12`

			#<10^5
			#echo "bit_score: ${bit_score}"
			#echo "e_value: ${e_value}"
			if [ "$(echo "${e_value} <= 1*10^-5" | bc -l)" -eq 0 ] ; then #>10^-5
			#	echo "${e_value} > e^-5, skip"
				continue
			#else
			#	echo "${e_value} < e^-5, OK"
			fi

			gene_id=`echo ${gene_id_line} | cut -d " " -f1`  #M00587:17:000000000-AK158:1:1101:14247:1241_1
			ref_id=` echo ${ref_id_line}  | cut -d " " -f1`  #sp|Q1RI08|PRIA_RICBR

	        #pfam==================
	        if [ ${db_type} = ${Pfam_id} ]; then
	            pfamid=`echo ${ref_id_line}  | cut -f1 -d ";" | cut -f3 -d " " | cut -f1 -d "."`
	            name=`  cat ${Pfam_annotation} | grep "^${pfamid}" -m 1 | cut -f5`
	            output_line="${gene_id}""   ""${pfamid}""   ""${name}"
	        else
				echo "Unknown error"
				exit 1
			fi	
			
			echo -e "${output_line}"
			echo -e "${output_line}">>${output_annotation}
		done
	fi

    #check
    if [ -z ${output_annotation} ]; then
        echo "Annotation would not complete successfully. Deleted."
        rm ${output_annotation}
    fi

else
    echo "skipped annotation"
    exit 0
fi

cat ${output_annotation}| sort | uniq >${output_annotation}_tmp
rm ${output_annotation}
mv ${output_annotation}_tmp ${output_annotation}

echo "All done."
./runtime.sh ${start_time}

exit 0
