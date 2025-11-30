#!/bin/bash
#$ -m be
#$ -cwd

function usage() {
    cat <<EOF
========================================================================================================================================
Description:
    $(basename ${0}) is a script for (meta)genome assenbly.
    Satoshi Hiraoka
    hiraokas@jamstec.go.jp
    Created: <2018
    History:  20230329 (update hifiasm 0.19.3)
    History:  20230415 (update hifiasm 0.19.4)
    History:  20250411 (add continue option in SPAdes)
Usage:
    $(basename ${0}) -i [filename] -t [software]
Required:
    ------------------------------------------------------------------------------------------------------------------------
    Single-end sequence:
    -i      Input filename; single-end mode (FASTQ; .fq) (!NOT officially SUPPRTED BY metaSPAdes when using Illumina) ( Not supported by MetaPlatanus!)
    
    Illumina sequence: (please keep this option order (1~6,0,c))***
    -1, -2  Input filename; pair-end mode           (FASTQ; .fq)      (SPAdes, Unicycler, MetaPlatanus, trinity)
    -0      Input filename; merged pair-end mode    (FASTQ; .fq)      (-1, -2 option is required) (SPAdes)
    -3, -4  Input filename; mait-pair mode          (FASTQ; .fq)      (-1, -2 option is required) (SPAdes)
    -5, -6  Input filename; multiple pair-end mode  (FASTQ; .fq)      (-1, -2 option is required) (SPAdes)
    -8, -9  Input filename; pair-end and pseudo pair-end (mate-pair fole but treated as pair-end with different orientation) mode 
                                                    (FASTQ; .fq)      (-1, -2 option is required) (SPAdes)
    -C      Input filename of trusted contig        (FASTQ; .fq)      (-3, -4 option is required) (SPAdes) 
    ------------------------------------------------------------------------------------------------------------------------

    -t      assemly software     [MetaPlatanus, megahit, SPAdes, metavelvet, (soap2), Unicycler, 
                                  canu, mira, sprai, Ray, FALCON, wtdbg2, metaflye, hifiasm, hifiasm_meta, hifiasm_Smeta
                                  SPAdesHybrid, OPERA,
                                  trinity]
    -s      estimated genome size (6m, 500k, 1g,  ...        for canu, wtdbg2)   #metaflye
                                  (100000000, 500000000, ... for sprai)
    -x      Sequencing platform  [illumina, rs, sq, ccs, ont]        (wtdbg2)
                                 [illumina, rs, sq, ccs, hifi, ont]  (flye, canu)
                                 [hifi]                              (hifiasm, hifiasm_meta, hifiasm_Smeta,metaflye)
    -c      Continue running from last available check point (megahit, SPAdes)
    -g      Genomic data, i.e. not metagenomic mode          (SPAdes)
    -r      Transcriptome mode, i.e., rnaSPAdes              (SPAdes)
Option:
    -T      THREADS (default: 6; 0: use all threads)
    -M      Memory space (default: 250)
                int (e.g., 250): SPAdes, canu, megahit, trinity 
                    - Max memory space is 192 (l) and 384 (mem) in DA system.

Currently unaveilable:
    #-L      minimum read length for assemby (wtdbg2, for pacbio and nanopore)
             (default: 5000)
    #-p      Kmer size (wtdbg2, for pacbio and nanopore)
             (default: 21)
========================================================================================================================================
EOF
}

usage_exit() {
	usage
	exit 1
}

if [ $# -le 0 ]; then
	usage_exit
fi

start_time=`date +%s`

meta_platanus="   ${HOME}/software/MetaPlatanus_v1.2.2_Linux_x86_64_pre_build/meta_platanus.pl"
megahit="         ${HOME}/software/MEGAHIT-1.2.9-Linux-x86_64-static/bin/megahit"
soap2="           ../module/SOAPdenovo2/SOAPdenovo-127mer"
SPAdes="          ${HOME}/software/SPAdes-3.15.0-Linux/bin/spades.py"
metavelvet="      ${HOME}/software/MetaVelvet-1.2.02"
canu="            ${HOME}/software/canu-2.2/bin/canu"
hifiasm="         ${HOME}/software/hifiasm-0.19.4/hifiasm"
hifiasm_meta="    ${HOME}/software/hifiasm-meta-hamtv0.3.1/hifiasm_meta"
mira="            ${HOME}/software/mira_4.0.2_linux-gnu_x86_64_static/bin/mira"
sprai="           ${HOME}/software/sprai-0.9.9.23/ezez4qsub_vx1.pl"
Celera_Assembler="${HOME}/software/wgs-8.3rc2/Linux-amd64/bin/"
ray="             ${HOME}/software/Ray-2.3.1/Ray"
FALCON="          ${HOME}/software/pitchfork/deployment/bin/fc_run.py"
wtdbg2="          ${HOME}/software/wtdbg-2.5_x64_linux/wtdbg2"
wtpoacns="        ${HOME}/software/wtdbg-2.5_x64_linux/wtpoa-cns"
flye="            flye"  #conda
OPERA="           ${HOME}/software/OPERA-MS/OPERA-MS.pl"
unicycler="       ${HOME}/software/Unicycler-0.4.8/unicycler-runner.py"
Trinity="         ${HOME}/software/trinityrnaseq-v2.13.2/Trinity"


python=`which python`  #"${HOME}/software/python2/bin/python"

#directory
output_dir="../assembly"

#init
assembly_type="single"  #single, double, MatePair_PairEnd
THREADS=6
_RAW=1
_NANOPORE=0
_CONTINUE=0
ESTIMATED_GENOME_SIZE=1000m
_MEMORY=250

#_L=5000
#_p=21
_SEQ_PLATFORM=""
_MODE=0

#--------------------------------------------------------------------------------------
#http://qiita.com/b4b4r07/items/dcd6be0bb9c9185475bb
while getopts T:i:t:h0:1:2:3:4:5:6:8:9:C:s:cM:gx:r OPT
do
	case $OPT in
		T)	THREADS=$OPTARG
			;;
		i)	INPUT_FILE=$OPTARG
			FILENAME=${INPUT_FILE##*/}
			BASE_FILENAME=${FILENAME%.*}
			EXT_FILENAME=${FILENAME##*.}
			assembly_type="single"
            ;;
        0)  INPUT_FILE_P0=$OPTARG
            FILENAME_P0=${INPUT_FILE_P0##*/}
            assembly_type="Merged_PairEnd"
            ;;
        1)	INPUT_FILE_P1=$OPTARG
			FILENAME_P1=${INPUT_FILE_P1##*/}
			BASE_FILENAME_P1=${FILENAME_P1%.*}
			EXT_FILENAME_P1=${FILENAME_P1##*.}
            #BASE_FILENAME_P1=${BASE_FILENAME_P1//_R1/}  #remove "_R1"
            BASE_FILENAME_P1=${BASE_FILENAME_P1%_*}  #remove "_R1" and "_1"
			assembly_type="double"
            ;;
        2)	INPUT_FILE_P2=$OPTARG
			FILENAME_P2=${INPUT_FILE_P2##*/}
			assembly_type="double"
            ;;
        3)  INPUT_FILE_P3=$OPTARG
            FILENAME_P3=${INPUT_FILE_P3##*/}
            assembly_type="MatePair_PairEnd"
            ;;
        4)  INPUT_FILE_P4=$OPTARG
            assembly_type="MatePair_PairEnd"
            ;;
        5)  INPUT_FILE_P5=$OPTARG
            assembly_type="Multiple_PairEnd"
            ;;
        6)  INPUT_FILE_P6=$OPTARG
            assembly_type="Multiple_PairEnd"
            ;;
        8)  INPUT_FILE_P8=$OPTARG
            FILENAME_P8=${INPUT_FILE_P8##*/}
            assembly_type="PairEnd_PseudoPairEnd"
            ;;
        9)  INPUT_FILE_P9=$OPTARG
            assembly_type="PairEnd_PseudoPairEnd"
            ;;
        C)  INPUT_FILE_C1=$OPTARG
            FILENAME_C1=${INPUT_FILE_C1##*/}
            if [ ${assembly_type} == "double" ]; then
                assembly_type="TrustedContigs_PairedEnd"
            else
                assembly_type="TrustedContigs_MatePair"
            fi
            ;;
        s)  ESTIMATED_GENOME_SIZE=$OPTARG
			;;
        t)	TOOL_TYPE=$OPTARG
            ;;
        M)	_MEMORY=$OPTARG
			;;
        #r)	_RAW=0
		#	;;
        #n)  _NANOPORE=1
        #    ;;
        x)  _SEQ_PLATFORM=$OPTARG
            ;;
        c)  _CONTINUE=1
            ;;
        g)  _MODE=1
            ;;
        r)  _MODE=2
            ;;
       	h)	usage_exit
			exit 0
			;;
		\?)	usage_exit
			;;
	esac
done

if [ -z ${TOOL_TYPE} ]; then
	echo "No input assembling tool."
	usage_exit
	exit 0
fi

if [ -z ${INPUT_FILE} ] && [ -z ${INPUT_FILE_P1} ] && [ -z ${INPUT_FILE_P3} ] ; then
    echo "No input file."
    usage_exit
    exit 0
fi

if [ ! -e ${output_dir} ]; then
    mkdir ${output_dir}
fi

echo ${BASE_FILENAME}
echo ${BASE_FILENAME_P1}

echo "assembling tool: ${TOOL_TYPE}"
case ${TOOL_TYPE} in

    #===========================
	"MetaPlatanus")		
    #===========================
            outputdir_MP=${output_dir}/MetaPlatanus_${BASE_FILENAME_P1}
            mkdir ${outputdir_MP}

            if [ ${assembly_type} = "single"  ]; then
                echo "Only pair-end reads were acceptable"
                break
            fi

            #command="${meta_platanus} cons_asm -IP1 ${INPUT_FILE_P1} ${INPUT_FILE_P2} -t ${THREADS} -o ${outputdir_MP}/MP_${BASE_FILENAME_P1} "  #>${outputdir_MP}/MP_${BASE_FILENAME_P1}_assemble_log.txt
            command="${meta_platanus} cons_asm -IP1 ${INPUT_FILE_P1} ${INPUT_FILE_P2} -t ${THREADS} -o MP_${BASE_FILENAME_P1} "  #>${outputdir_MP}/MP_${BASE_FILENAME_P1}_assemble_log.txt
            echo ${command}; eval ${command}


        #old MetaPlatanus version
        #    if [ ${assembly_type} = "single"  ]; then
        #        echo "assemble"
        #        command="${meta_platanus} assemble -f ${INPUT_FILE} -t ${THREADS} -o ${outputdir_MP}/MP_${BASE_FILENAME} 2>${outputdir_MP}/MP_${BASE_FILENAME}_assemble_log.txt"
        #        echo ${command}; eval ${command}
        #
        #        echo "iterate"
        #        command="${meta_platanus} iterate -c ${outputdir_MP}/MP_${BASE_FILENAME}_contig.fa -k ${outputdir_MP}/MP_${BASE_FILENAME}_kmer_occ.bin -ip1 ${INPUT_FILE} -t ${THREADS} -tmp ${outputdir_MP} -o ${outputdir_MP}/MP_${BASE_FILENAME} 2>${outputdir_MP}/MP_${BASE_FILENAME}_iterate_log.txt"
        #        echo ${command}; eval ${command}
        #
        #        echo "cluster_scaffold"
        #        command="${meta_platanus} cluster_scaffold -c ${outputdir_MP}/MP_${BASE_FILENAME}_iterativeAssembly.fa -ip1 ${INPUT_FILE} -t ${THREADS} -tmp ${outputdir_MP} -o ${outputdir_MP}/MP_${BASE_FILENAME} 2>${outputdir_MP}/MP_${BASE_FILENAME}_cluster_scaffold_log.txt"
        #        echo ${command}; eval ${command}
        #
        #    elif [ ${assembly_type} = "double"  ]; then
        #        echo "assemble"
        #        command="${meta_platanus} assemble -f ${INPUT_FILE_P1} ${INPUT_FILE_P2} -t ${THREADS} -tmp ${outputdir_MP} -o ${outputdir_MP}/MP_${BASE_FILENAME} 2>${outputdir_MP}/MP_${BASE_FILENAME}_assemble_log.txt"
        #        echo ${command}; eval ${command}
        #
        #        echo "iterate"
        #        command="${meta_platanus} iterate -c ${outputdir_MP}/MP_${BASE_FILENAME}_contig.fa -k ${outputdir_MP}/MP_${BASE_FILENAME}_kmer_occ.bin -IP1 ${INPUT_FILE_P1} ${INPUT_FILE_P2} -t ${THREADS} -tmp ${outputdir_MP} -o ${outputdir_MP}/MP_${BASE_FILENAME} 2>${outputdir_MP}/MP_${BASE_FILENAME}_iterate_log.txt"
        #        echo ${command}; eval ${command}
        #
        #        echo "cluster_scaffold"
        #        command="${meta_platanus} cluster_scaffold -c ${outputdir_MP}/MP_${BASE_FILENAME}_iterativeAssembly.fa -IP1 ${INPUT_FILE_P1} ${INPUT_FILE_P2} -t ${THREADS} -tmp ${outputdir_MP} -o ${outputdir_MP}/MP_${BASE_FILENAME} 2>${outputdir_MP}/MP_${BASE_FILENAME}_cluster_scaffold_log.txt"
        #        echo ${command}; eval ${command}
        #    fi
		;;

    #===========================
	"megahit")		
    #===========================
	        if   [ ${_CONTINUE} = 0 ]; then
                option_continue=""
            elif [ ${_CONTINUE} = 1 ]; then
                option_continue="--continue"
            fi
            command="${megahit} -r ${INPUT_FILE} --presets meta-sensitive -o ${output_dir}/megahit_${BASE_FILENAME} -t ${THREADS} -m ${_MEMORY}000000000 ${option_continue}"
            echo ${command}
            ${command}
		;;	

    #===========================
	"soap2")		
    #===========================
			echo "***no implement***"
			#https://github.com/aquaskyline/SOAPdenovo2/blob/master/README.md
			
			#${soap2} all -r ${1} --presets meta -o ${output_dir}/soap2_${BASE_FILENAME} -t ${THREADS}
			#${soap2} all -s config_file -K 127 -R -o graph_prefix 1>${output_dir}/soap2_${BASE_FILENAME}.log 2>${output_dir}/soap2_${BASE_FILENAME}.err  

		;;	

    #===========================
	"SPAdes")
    #===========================
            prefix_option=""
	        if [ ${_MODE} = 0 ]; then
                echo "Metaenome mode"
                basic_option="--meta"
                prefix_option="meta"
            elif [ ${_MODE} = 1 ]; then
                echo "Genome mode"
                basic_option="--isolate"
            elif [ ${_MODE} = 2 ]; then
                echo "RNA (transcriptome) mode"
                basic_option="--rna" 
                prefix_option="rna"
			fi

            source ${HOME}/miniconda3/etc/profile.d/conda.sh
            conda activate py38

            if   [ ${assembly_type} = "single"  ]; then
                outputPass=${output_dir}/${prefix_option}SPAdes_${BASE_FILENAME}
                if [ ${_CONTINUE} = 1 ]; then
                    ${python} ${SPAdes} -o ${outputPass} --continue
                else
    				${python} ${SPAdes} -s ${INPUT_FILE}                        -o ${outputPass}    -t ${THREADS} -m ${_MEMORY} ${basic_option} ${option_continue}
	            fi		
            elif [ ${assembly_type} = "double"  ]; then
                outputPass=${output_dir}/${prefix_option}SPAdes_${BASE_FILENAME_P1}
                if [ ${_CONTINUE} = 1 ]; then
                    ${python} ${SPAdes} -o ${outputPass} --continue
                else
    				${python} ${SPAdes} -1 ${INPUT_FILE_P1} -2 ${INPUT_FILE_P2} -o ${outputPass} -t ${THREADS} -m ${_MEMORY} ${basic_option} ${option_continue}
                fi        
            elif [ ${assembly_type} = "MatePair_PairEnd" ]; then
                outputPass=${output_dir}/${prefix_option}SPAdes_PE-MP_${BASE_FILENAME_P1}
                ${python} ${SPAdes} --pe-1 1 ${INPUT_FILE_P1} --pe-2 1  ${INPUT_FILE_P2}  --mp-1 2 ${INPUT_FILE_P3} --mp-2 2 ${INPUT_FILE_P4}  \
                                                                            -o ${outputPass} -t ${THREADS} -m ${_MEMORY} ${basic_option}  ${option_continue}# # --mp-or 1 rf
            
            elif [ ${assembly_type} = "Merged_PairEnd" ]; then
                outputPass=${output_dir}/${prefix_option}SPAdes_PE-Merged_${BASE_FILENAME_P1}
                ${python} ${SPAdes} --pe-1 1 ${INPUT_FILE_P1} --pe-2 1  ${INPUT_FILE_P2}  --merged ${INPUT_FILE_P0}\
                                                                            -o ${outputPass} -t ${THREADS} -m ${_MEMORY} ${basic_option}  ${option_continue}   
            
            elif [ ${assembly_type} = "Multiple_PairEnd" ]; then
                outputPass=${output_dir}/${prefix_option}SPAdes_Multi-PE_${BASE_FILENAME_P1}
                ${python} ${SPAdes} --pe-1 1 ${INPUT_FILE_P1} --pe-2 1  ${INPUT_FILE_P2}  --pe-1 2 ${INPUT_FILE_P5} --pe-2 2  ${INPUT_FILE_P6}\
                                                                            -o ${outputPass} -t ${THREADS} -m ${_MEMORY} ${basic_option}  ${option_continue}   
            
            elif [ ${assembly_type} = "TrustedContigs_PairedEnd" ]; then
                outputPass=${output_dir}/${prefix_option}SPAdes_TC-PE_${FILENAME_C1}-${BASE_FILENAME_P1}
                ${python} ${SPAdes} --pe-1 1 ${INPUT_FILE_P1} --pe-2 1  ${INPUT_FILE_P2}  --trusted-contigs ${INPUT_FILE_C1}   \
                                                                            -o ${outputPass} -t ${THREADS} -m ${_MEMORY} ${basic_option}    ${option_continue} 
            
            elif [ ${assembly_type} = "TrustedContigs_MatePair" ]; then
                outputPass=${output_dir}/${prefix_option}SPAdes_TC-MP_${FILENAME_C1}-${BASE_FILENAME_P3}
                ${python} ${SPAdes} --hqmp-1 1 ${INPUT_FILE_P3} --hqmp-2 1  ${INPUT_FILE_P4}  --trusted-contigs ${INPUT_FILE_C1}  --hqmp-or 1 rf \
                                                                            -o ${outputPass} -t ${THREADS} -m ${_MEMORY} ${basic_option}   ${option_continue}  
            
            elif [ ${assembly_type} = "PairEnd_PseudoPairEnd" ]; then
                outputPass=${output_dir}/${prefix_option}SPAdes_PE-PPE_${BASE_FILENAME_P1}-${FILENAME_P8}
                ${python} ${SPAdes} --pe-1 1 ${INPUT_FILE_P1} --pe-2 1  ${INPUT_FILE_P2}  --pe-1 2 ${INPUT_FILE_P8} --pe-2 2  ${INPUT_FILE_P9}  --pe-or 2 rf \
                                                                            -o ${outputPass} -t ${THREADS} -m ${_MEMORY} ${basic_option}  ${option_continue}   
            
            else
				echo "inccorect assembly_type"
                exit
			fi

            #remove files for reduce strage usage
            #rm ${outputPass}/K[1-9][1-9] -r
            #rm ${outputPass}/corrected -r
            #rm ${outputPass}/first_pe_contigs.fasta
            #rm ${outputPass}/before_rr.fasta
            #rm ${outputPass}/strain_graph.gfa
            #rm ${outputPass}/misc -r
            #rm ${outputPass}/rmp -r

            #make link for final contigs
            #cd ${output_dir}
            #ln -s 

		;;

    #===========================
    "SPAdesHybrid")
    #===========================
            if [ ${_MODE} = 0 ]; then
                echo "Metaenome mode"
                basic_option="--meta"
            else
                echo "Genome mode"
                basic_option="--isolate"
            fi

            spades.py -t ${THREADS} -k auto --careful -1 ${INPUT_FILE_P1} -2 ${INPUT_FILE_P2} --nanopore ${INPUT_FILE} \
            -o ${output_dir}/SPAdes_${BASE_FILENAME} ${basic_option} -m ${_MEMORY} 

        ;;

    #===========================
    "Unicycler")
    #===========================
            if [ ${_MODE} = 0 ]; then
                echo "Metaenome mode"
                basic_option="--meta"
            else
                echo "Genome mode"
                basic_option="--isolate"
            fi

            if   [ ${assembly_type} = "single"  ]; then
                ${unicycler} -s ${INPUT_FILE} -o ${output_dir}/Unicycler_${BASE_FILENAME} --no_pilon -t ${THREADS}
            
            elif [ ${assembly_type} = "double"  ]; then
                ${unicycler} -1 ${INPUT_FILE_P1} -2 ${INPUT_FILE_P2} -o ${output_dir}/Unicycler_${FILENAME_P1} --no_pilon -t ${THREADS}
            fi

        ;;

    #===========================
    "metavelvet")
    #===========================
            mkdir                      ${output_dir}/metavelvet_${BASE_FILENAME}
            ${metavelvet}/velveth      ${output_dir}/metavelvet_${BASE_FILENAME} 51  -fasta -long  ${INPUT_FILE} 
            ${metavelvet}/velvetg      ${output_dir}/metavelvet_${BASE_FILENAME}     -exp_cov auto -ins_length 260
            ${metavelvet}/meta-velvetg ${output_dir}/metavelvet_${BASE_FILENAME} [-ins_length 260] | tee logfile
        ;;

    #===========================
	"canu")
    #===========================
			if   [ -z ${_SEQ_PLATFORM} ] ; then
                echo "error: unset sequencing platform"
                exit
            elif [ ${_SEQ_PLATFORM} = "rs" ] || [ ${_SEQ_PLATFORM} = "sq" ] ; then
				SEQ_TYPE="-pacbio-raw"
				SIMBOL="PR"
			elif [ ${_SEQ_PLATFORM} = "ccs" ] ; then
				SEQ_TYPE="-pacbio-corrected"
				SIMBOL="PC"
            elif [ ${_SEQ_PLATFORM} = "hifi" ] ; then
                SEQ_TYPE="-pacbio-hifi"
                SIMBOL="HiFi"
            elif [ ${_SEQ_PLATFORM} = "ont" ] ; then
                SEQ_TYPE="-nanopore-raw"
                SIMBOL="ONT"
            else
                echo "canu type error"
                exit
            fi

            #############
            #minOverlapLength=300  #def: 500
            minOverlapLength=500  #def: 500
            #correctedErrorRate=0.055  #def: 0.045
            correctedErrorRate=0.045  #def: 0.045

            #work_dir=${output_dir}/${TOOL_TYPE}_${SIMBOL}_${BASE_FILENAME}_${ESTIMATED_GENOME_SIZE}_${minOverlapLength}_${correctedErrorRate}
            #command="${canu} -p ${FILENAME} -d ${output_dir}/canu_${BASE_FILENAME}_${SIMBOL}_${ESTIMATED_GENOME_SIZE}${minOverlapLength}${correctedErrorRate} genomeSize=${ESTIMATED_GENOME_SIZE} ${SEQ_TYPE} ${INPUT_FILE} -useGrid=false -maxThreads=${THREADS} ovsMethod=sequential minOverlapLength=${minOverlapLength} correctedErrorRate=${correctedErrorRate} gnuplotTested=true"    
            #############
            
            work_dir=${output_dir}/${TOOL_TYPE}_${SIMBOL}_${BASE_FILENAME}  #_${ESTIMATED_GENOME_SIZE}
            prefix_file=${TOOL_TYPE}_${SIMBOL}_${BASE_FILENAME}  #_${ESTIMATED_GENOME_SIZE}

            if [ ${THREADS} = 0 ]; then
			    command="${canu} -p ${prefix_file} -d ${work_dir} genomeSize=${ESTIMATED_GENOME_SIZE} \
                ${SEQ_TYPE} ${INPUT_FILE} -useGrid=false ovsMethod=sequential"
            else
                #-p humans_skin -d ../assembly_test2 genomeSize=6.0m -pacbio-raw ../test_dataset/SRR2420276.fa -useGrid=false
    			command="${canu} -p ${prefix_file} -d ${work_dir} genomeSize=${ESTIMATED_GENOME_SIZE} \
                ${SEQ_TYPE} ${INPUT_FILE} -useGrid=false -maxThreads=${THREADS} -maxMemory=${_MEMORY} gnuplot=undef"  #  merylThreads=1
            fi
            echo ${command}
            ${command}

            #clean
            rm -r ${work_dir}/canu-scripts
            rm -r ${work_dir}/unitigging
            rm -r ${work_dir}/${prefix_file}.seqStore
            rm -r ${work_dir}/${prefix_file}.unassembled.fasta

		;;

    #===========================
    "mira")
    #===========================
            mkdir ${output_dir}/mira_${BASE_FILENAME}
            mkdir ${output_dir}/mira_${BASE_FILENAME}/data
            ln -s ${INPUT_FILE} ${output_dir}/mira_${BASE_FILENAME}/data/${BASE_FILENAME}.${EXT_FILENAME}
            mkdir ${output_dir}/mira_${BASE_FILENAME}/assemblies
            mkdir ${output_dir}/mira_${BASE_FILENAME}/assemblies/1sttrial

            cat <<EOF >${output_dir}/mira_${BASE_FILENAME}/manifest.conf
                # Example for a manifest describing a de-novo assembly with
                # PacBio CCS

                # First part: defining some basic things
                # In this example, we just give a name to the assembly
                #  and tell MIRA it should map a genome in accurate mode

                project = mira_${BASE_FILENAME}
                job = genome,denovo,accurate

                # The second part defines the sequencing data MIRA should load and assemble
                # The data is logically divided into "readgroups"


                parameters = COMMON_SETTINGS -GENERAL:number_of_threads=${THREADS} \\
                             -HS:nrr=20 \\
                             PCBIOHQ_SETTINGS -CL:pec=yes 
                readgroup = SomeUnpairedIlluminaReadsIGotFromTheLab
                data = ${INPUT_FILE}
                technology=pcbiohq
EOF
            cat ${output_dir}/mira_${BASE_FILENAME}/manifest.conf
            ${mira} ${output_dir}/mira_${BASE_FILENAME}/manifest.conf >& ${output_dir}/mira_${BASE_FILENAME}/assemblies/log_assembly.txt
        ;;

    #===========================
    "sprai")
    #===========================
            mkdir ${output_dir}/sprai_${BASE_FILENAME}_${ESTIMATED_GENOME_SIZE}
            current_pwd=`pwd`
            cd ${output_dir}/sprai_${BASE_FILENAME}_${ESTIMATED_GENOME_SIZE}
            cat <<EOF >ec.spec
                #### common ####
                # input_for_database: filtered subreads in fasta or fastq format
                input_for_database ../${INPUT_FILE}

                # min_len_for_query: the subreads longer than or equal to this value will be corrected
                min_len_for_query 500

                #if you don't know the estimated genome size, give a large number
                estimated_genome_size ${ESTIMATED_GENOME_SIZE}
                #if you don't know the estimated depth of coverage, give 0
                estimated_depth 0

                # ca_path: where Celera Assembler exist in
                #ca_path /home/imai/wgs/Linux-amd64/bin/
                ca_path ${Celera_Assembler}

                # the number of processes used by all vs. all alignment
                # = 'partition' (in single node mode)
                # = 'pre_partition' * 'partition' (in many node mode)
                pre_partition 1
                partition 6

                # sprai prefer full paths
                # if you use ezez4qsub*.pl. you MUST specify blast_path & sprai_path
                # blast_path: where blastn and makeblastdb exist in
                blast_path /usr/local/bin/
                # sprai_path: where binaries of sprai (bfmt72s, nss2v_v3 and so on) exist in
                #sprai_path ../../software/sprai-0.9.9.23/
                sprai_path $(dirname ${sprai})

                #### many node mode (advanced) ####

                #sge: options for all the SGE jobs (used by ezez4qsub_vx1.pl)
                #sge -soft -l ljob,lmem,sjob
                #queue_req: additional options for all the SGE jobs (used by ezez4qsub_vx1.pl and ezez4makefile_v4.pl)
                #queue_req -l s_vmem=4G -l mem_req=4
                #longestXx_queue_req: if valid, displaces queue_req (used by ezez4qsub_vx1.pl)
                #longestXx_queue_req -l s_vmem=64G -l mem_req=64
                #BLAST_RREQ: additional options for SGE jobs of all vs. all alignment (used by ezez4qsub.pl and ezez4makefile_v4.pl)
                #BLAST_RREQ -pe def_slot 4
                #ec_rreq: options for error correction (used by ezez4makefile_v4.pl)
                #ec_rreq -l s_vmem=4G -l mem_req=4

                #### common (advanced) ####

                # used by blastn
                word_size 18
                evalue 1e-50
                num_threads 1
                max_target_seqs 100

                #valid_voters 11

                #trim: both ends of each alignment by blastn will be trimmed 'trim' bases to detect chimeric reads
                trim 42

                # if not 0, use only one subread per one molecule
                use_one_subread 0

                # direct_vote & copy_blastdb are used by ezez4makefile_v4.pl
                direct_vote 0
                # skip writing the blast results once to disk before selecting
                # voters (default 1), or write to the disk to allow multiple use
                # of the blast results for different number of voters (0)
                copy_blastdb 1
                # copy the blastdb to $TMP, presumably set by gridengine to local node,
                # and use it during execution. This could reduce NFS access per job, but may
                # increase the total transfer if each node is running multiple jobs.
EOF
            #cat ${output_dir}/sprai_${BASE_FILENAME}_${ESTIMATED_GENOME_SIZE}/ec.spec
            #command="${sprai} ${output_dir}/sprai_${BASE_FILENAME}_${ESTIMATED_GENOME_SIZE}/ec.spec ../../software/sprai-0.9.9.23/pbasm.spec "
            command="${sprai} ec.spec $(dirname ${sprai})/pbasm.spec"
            echo ${command}
            ${command}
            cd ${current_pwd}
        ;;

    #===========================
    "Ray")
    #===========================
            /usr/local/bin/mpiexec -n ${THREADS} ${ray} -s ${INPUT_FILE} -o ${output_dir}/ray_${BASE_FILENAME} 
        ;;

    #===========================
    "FALCON")
    #===========================
            mkdir ${output_dir}/falcon_${BASE_FILENAME}
            current_pwd=`pwd`
            cd    ${output_dir}/falcon_${BASE_FILENAME}
            source ${fitchfork_env}
            cat <<EOF >input.fofn
                ${INPUT_FILE}
EOF
            cat <<EOF >fc_run.cfg
                [General]
                skip_check = true

                #job_type = local
                job_type = sge

                # list of files of the initial subread fasta files
                input_fofn = ${output_dir}/falcon_${BASE_FILENAME}/input.fofn

                input_type = raw
                #input_type = preads
                #genome_size = 100000000
                #seed_coverage = 10

                # The length cutoff used for seed reads used for initial mapping
                length_cutoff = 12000

                # The length cutoff used for seed reads usef for pre-assembly
                length_cutoff_pr = 12000

                # Cluster queue setting
                sge_option_da =  -pe make 8  
                sge_option_la =  -pe make 2  
                sge_option_pda = -pe make 8  
                sge_option_pla = -pe make 2  
                sge_option_fc =  -pe make 24 
                sge_option_cns = -pe make 8  

                # concurrency settgin
                pa_concurrent_jobs = 32
                cns_concurrent_jobs = 32
                ovlp_concurrent_jobs = 32

                # overlapping options for Daligner
                pa_HPCdaligner_option =  -v -dal4 -t16 -e.70 -l1000 -s1000
                ovlp_HPCdaligner_option = -v -dal4 -t32 -h60 -e.96 -l500 -s1000

                pa_DBsplit_option = -x500 -s50
                ovlp_DBsplit_option = -x500 -s50

                # error correction consensus optione
                falcon_sense_option = --output_multi --min_idt 0.70 --min_cov 4 --max_n_read 200 --n_core ${THREADS}

                # overlap filtering options
                overlap_filtering_setting = --max_diff 100 --max_cov 100 --min_cov 20 --bestn 10

                use_tmpdir = false
EOF
            command="python ${FALCON} fc_run.cfg"
            #command="${FALCON} ${output_dir}/falcon_${BASE_FILENAME}/manifest.conf"
            echo ${command}
            ${command}
            cd ${current_pwd}
        ;;

    #===========================
    "wtdbg2")
    #===========================
        if   [ -z ${_SEQ_PLATFORM} ] ; then
                echo "error: unset sequencing platform"
                exit
            elif [ ${_SEQ_PLATFORM} = "rs" ] || [ ${_SEQ_PLATFORM} = "sq" ] ; then
                SEQ_TYPE=${_SEQ_PLATFORM}
                SIMBOL="PR"
            elif [ ${_SEQ_PLATFORM} = "ccs" ] ; then
                SEQ_TYPE=${_SEQ_PLATFORM}
                SIMBOL="PC"
            elif [ ${_SEQ_PLATFORM} = "ont" ] ; then
                SEQ_TYPE=${_SEQ_PLATFORM}
                SIMBOL="ONT"
            else
                echo "wtdbg2 type error"
                exit
            fi

            prefix_dir=${output_dir}/wtdbg2_${SIMBOL}_${BASE_FILENAME}_${ESTIMATED_GENOME_SIZE}
            mkdir  ${prefix_dir}
            prefix_file=${prefix_dir}/wtdbg2_${SIMBOL}_${BASE_FILENAME}_${ESTIMATED_GENOME_SIZE}
            
            # assemble long reads
            if [ ! -e ${prefix_file}.ctg.lay.gz ]; then
                ${wtdbg2}   -t ${THREADS} -i ${INPUT_FILE} -o ${prefix_file} -g ${ESTIMATED_GENOME_SIZE} -x ${SEQ_TYPE} #-L ${_L} -p ${_p}
            else
                echo "skip wtdbg2"
            fi

            # derive consensus
            if [ ! -e ${prefix_file}.ctg.fa ]; then
                ${wtpoacns} -t ${THREADS} -i ${prefix_file}.ctg.lay.gz -o ${prefix_file}.ctg.fa
            else
                echo "skip wtpoacns"
            fi
            # polish consensus, not necessary if you want to polish the assemblies using other tools
            #minimap2 -t ${THREADS} -x map-pb -a prefix.ctg.lay.fa reads.fa.gz | samtools view -Sb - >prefix.ctg.lay.map.bam
            #samtools sort prefix.ctg.lay.map.bam prefix.ctg.lay.map.srt
            #samtools view prefix.ctg.lay.map.srt.bam | ./wtpoa-cns -t ${THREADS} -d prefix.ctg.lay.fa -i - -fo prefix.ctg.lay.2nd.fa

            #make graph file
            gunzip ${prefix_file}.3.dot.gz
            ~/software/wtdbg2/scripts/wtdbg-dot2gfa.pl ${prefix_file}.3.dot > ${prefix_file}.3.gfa
        ;;

    #===========================
    "hifiasm")
    #===========================
            if   [ -z ${_SEQ_PLATFORM} ] ; then
                echo "error: unset sequencing platform"
                exit
            elif [ ${_SEQ_PLATFORM} = "hifi" ] ; then
                SEQ_TYPE=${_SEQ_PLATFORM}
                SIMBOL="HiFi"
            else
                echo "hifiasm type error"
                exit
            fi

            prefix_dir=${output_dir}/hifiasm_${SIMBOL}_${BASE_FILENAME}
            mkdir  ${prefix_dir}
            prefix_file=${prefix_dir}/hifiasm_${SIMBOL}_${BASE_FILENAME}
            
            command="${hifiasm} -o ${prefix_file} -t ${THREADS} ${INPUT_FILE} -l0"
            echo ${command}
            ${command}

            #convert
            cat ${prefix_file}.bp.p_ctg.gfa |awk '/^S/{print ">"$2"\n"$3}' | fold > ${prefix_file}.contig.fa

            #reduce strage
            rm ${prefix_file}.ov*
            rm ${prefix_file}.r_*
            rm ${prefix_file}.ec*

            #make link
            ln -s ${prefix_file}.contig.fa ${prefix_dir}.fa 
        ;;

    #===========================
    "hifiasm_meta")
    #===========================
            if   [ -z ${_SEQ_PLATFORM} ] ; then
                echo "error: unset sequencing platform"
                exit
            elif [ ${_SEQ_PLATFORM} = "hifi" ] ; then
                SEQ_TYPE=${_SEQ_PLATFORM}
                SIMBOL="HiFi"
            else
                echo "hifiasm type error"
                exit
            fi

            prefix_dir=${output_dir}/hifiasmMeta_${SIMBOL}_${BASE_FILENAME}
            mkdir  ${prefix_dir}
            prefix_file=${prefix_dir}/hifiasmMeta_${SIMBOL}_${BASE_FILENAME}
            
            #command="${hifiasm_meta} -o ${prefix_file} -t ${THREADS} ${INPUT_FILE} 2> ${prefix_dir}/asm.log"
            command="${hifiasm_meta} -o ${prefix_file} -t ${THREADS} ${INPUT_FILE}"
            echo ${command}
            eval ${command}

            #convert
            cat ${prefix_file}.p_ctg.gfa |awk '/^S/{print ">"$2"\n"$3}' | fold > ${prefix_file}.contig.fa

            #reduce strage
            rm ${prefix_file}.ov*
            rm ${prefix_file}.r_*
            rm ${prefix_file}.ec* 
            rm ${prefix_file}.a_ctg.*
            rm ${prefix_file}.p_utg.*

            #make link
            ln -s ${prefix_file}.contig.fa ${prefix_dir}.fa 

        ;;

    #===========================
    "hifiasm_Smeta")
    #===========================
            if   [ -z ${_SEQ_PLATFORM} ] ; then
                echo "error: unset sequencing platform"
                exit
            elif [ ${_SEQ_PLATFORM} = "hifi" ] ; then
                SEQ_TYPE=${_SEQ_PLATFORM}
                SIMBOL="HiFi"
            else
                echo "hifiasm type error"
                exit
            fi

            prefix_dir=${output_dir}/hifiasmSmeta_${SIMBOL}_${BASE_FILENAME}
            mkdir  ${prefix_dir}
            prefix_file=${prefix_dir}/hifiasmSmeta_${SIMBOL}_${BASE_FILENAME}
            
            #command="${hifiasm_meta} -o ${prefix_file} -t ${THREADS} ${INPUT_FILE} 2> ${prefix_dir}/asm.log"
            command="${hifiasm_meta} -o ${prefix_file} -t ${THREADS} ${INPUT_FILE} -S --lowq-10 50"
            echo ${command}
            eval ${command}

            #convert
            cat ${prefix_file}.p_ctg.gfa |awk '/^S/{print ">"$2"\n"$3}' | fold > ${prefix_file}.contig.fa

            #reduce strage
            rm ${prefix_file}.ov*
            rm ${prefix_file}.r_*
            rm ${prefix_file}.ec* 
        ;;

    #===========================
    "metaflye")
    #===========================
            source ${HOME}/miniconda3/etc/profile.d/conda.sh
            conda activate py39

            if   [ -z ${_SEQ_PLATFORM} ] ; then
                echo "error: unset sequencing platform"
                exit
            elif [ ${_SEQ_PLATFORM} = "rs" ] || [ ${_SEQ_PLATFORM} = "sq" ] ; then
                SEQ_TYPE="--pacbio-raw"
                SIMBOL="PR"
            elif [ ${_SEQ_PLATFORM} = "ccs" ] ; then
                SEQ_TYPE="--pacbio-corr"
                SIMBOL="PC"
            elif [ ${_SEQ_PLATFORM} = "hifi" ] ; then
                SEQ_TYPE="--pacbio-hifi"
                SIMBOL="HiFi"
            elif [ ${_SEQ_PLATFORM} = "ont" ] ; then
                SEQ_TYPE="--nano-raw"
                SIMBOL="ONT"
            else
                echo "metaflye type error"
                exit
            fi
            prefix_dir=${output_dir}/metaflye_${SIMBOL}_${BASE_FILENAME}  #_${ESTIMATED_GENOME_SIZE}
            mkdir ${prefix_dir}
            prefix_file=${prefix_dir}/metaflye_${SIMBOL}_${BASE_FILENAME}.fasta  #_${ESTIMATED_GENOME_SIZE}

            ${flye} ${SEQ_TYPE} ${INPUT_FILE} -t ${THREADS} --out-dir ${prefix_dir} --meta   #  --asm-coverage 50 --genome-size ${ESTIMATED_GENOME_SIZE} 
            mv ${prefix_dir}/assembly.fasta ${prefix_file}

            #clean up
            rm ${prefix_dir}/[0-4]0-* -r

        ;;     

    #===========================
    "OPERA")
    #===========================
            if   [ -z ${_SEQ_PLATFORM} ] ; then
                echo "error: unset sequencing platform"
                exit
            elif [ ${_SEQ_PLATFORM} = "rs" ] || [ ${_SEQ_PLATFORM} = "sq" ] ; then
                SEQ_TYPE="--pacbio-raw"
                SIMBOL="PR"
            elif [ ${_SEQ_PLATFORM} = "ccs" ] ; then
                SEQ_TYPE="--pacbio-corr"
                SIMBOL="PC"
            elif [ ${_SEQ_PLATFORM} = "ont" ] ; then
                SEQ_TYPE="--nano-raw"
                SIMBOL="ONT"
            else
                echo "flye type error"
                exit
            fi
            prefix_dir=${output_dir}/flye_${SIMBOL}_${BASE_FILENAME}_${ESTIMATED_GENOME_SIZE}
            mkdir ${prefix_dir}
            prefix_file=${prefix_dir}/flye_${SIMBOL}_${ESTIMATED_GENOME_SIZE}_${BASE_FILENAME}.fasta

            perl ${OPERA} \
                 --short-read1 ${INPUT_FILE_P1} \
                 --short-read2 ${INPUT_FILE_P2} \
                 --long-read   ${INPUT_FILE} \
                 --out-dir     ${prefix_dir} \
                 --num-processors ${THREADS} \
                 --polishing
        ;;    

    #===========================
    "trinity")
    #===========================

            source ${HOME}/miniconda3/etc/profile.d/conda.sh
            conda activate py38
            
            prefix=${output_dir}/trinity_${BASE_FILENAME}
            echo ${prefix}.Trinity.fasta

            if [ -e  ${prefix}.Trinity.fasta ]; then
                echo "Assembled file already exist."
                echo "Exit."
                exit 0
            fi

            if   [ ${assembly_type} = "single"  ]; then
                Trinity --seqType fq --single ${INPUT_FILE}                            --CPU ${THREADS} --max_memory ${_MEMORY}G --full_cleanup --output ${prefix}
            
            elif [ ${assembly_type} = "double"  ]; then
                Trinity --seqType fq --left ${INPUT_FILE_P1} --right ${INPUT_FILE_P2}  --CPU ${THREADS} --max_memory ${_MEMORY}G --full_cleanup --output ${prefix}
            fi


            #${flye} ${SEQ_TYPE} ${INPUT_FILE} --genome-size ${ESTIMATED_MODEENOME_SIZE} -t ${THREADS} --out-dir ${prefix_dir} --meta #  --asm-coverage 50
            
        ;;     
    
    #===========================
    *) 
    #===========================
            echo "Incorrect option: Undefined assembling tool"
            usage_exit
        ;;

esac

end_time=`date +%s`
PT=$((end_time - start_time))
H=` expr ${PT} / 3600`
PT=`expr ${PT} % 3600`
M=` expr ${PT} / 60`
S=` expr ${PT} % 60`
echo "Run Time: ${H}h ${M}m ${S}s"


exit 0
