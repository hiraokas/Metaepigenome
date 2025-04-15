# Metaepigenome (under development)

Metaepigenomics is a powerfll culture-independent method to reveal epigenomic landscape in microbial community. Here, we developed a bioinformatic workflow for metaepigenomics.

Please note that the scripts were prepared for the analysis of the original studies. This means that the scripts are not strictly concatenated as a stand-alone research pipeline and vilidated for other perspectives. The analysis have been performed on [the supercomputing system at National Institute of Genetics (NIG), Research Organization of Information and Systems (ROIS)](https://sc.ddbj.nig.ac.jp/en/), and [the Earth Simulator systems at JAMSTEC](https://www.jamstec.go.jp/es/en/).

Main script and related modules are stored under src/ directory. 
The official source code repository is at https://github.com/hiraokas/Metaepigenome.

## Code
The codes are written in shell script and python.

| File                    | Description |
----|---- 
| XXX.sh       | XXX |
| **mainScript_XXX.sh**  | Main script in this study |

## Dataset
| File                    | Description |
----|---- 
|XXX.fasta| XXX |

## Dependencies
- [Prodigal](https://github.com/hyattpd/Prodigal) - CDS prediction
- [DIAMOND](https://github.com/bbuchfink/diamond) - Similarity search
- [SeqKit](https://bioinf.shenwei.me/seqkit/) - Sequence manipulation including length filtering
- [MMseq2](https://github.com/soedinglab/MMseqs2) - Sequence clustering
- [MAFFT](https://mafft.cbrc.jp/alignment/software/) - Sequence alignment
- [FastTree2](https://www.microbesonline.org/fasttree/) - Phylogenetic tree prediction
- [Bowtie2](https://bowtie-bio.sourceforge.net/bowtie2/index.shtml) - Read mapping
- [Nonpareil3](https://github.com/lmrodriguezr/nonpareil) - Metagenomic coverage estimation

Also we used some tools and databases for detailed data analysis in this study.
- [MEGA X](https://www.megasoftware.net/) - Phylogenetic tree analysis

## Usage 

TBA

## Citation 
Hiraoka S. in prep. 
```
Email: hiraokas@jamstec.go.jp
```
