# Metaepigenome (under development)

Metaepigenomics is a powerfll culture-independent method to reveal epigenomic landscape in microbial community. Here, we are developing a bioinformatic workflow for metaepigenomi analysis.

Please note that the scripts were developed for the analysis of the original studies. This means that the scripts are not strictly concatenated as a stand-alone research pipeline and vilidated for other perspectives. The analysis have been performed on [the supercomputing system at National Institute of Genetics (NIG), Research Organization of Information and Systems (ROIS)](https://sc.ddbj.nig.ac.jp/en/), and [the Earth Simulator systems at JAMSTEC](https://www.jamstec.go.jp/es/en/).

Main script and related modules are stored under src/ directory. 
The official source code repository is at https://github.com/hiraokas/Metaepigenome.

### Overview
<img width="821" height="489" alt="Metaepigenome_overview" src="https://github.com/user-attachments/assets/9b8f3d0d-5996-4dcd-8053-788e1eda7a31" />

### Main step
- Metagenome assembly
- Binning
- MAG/SAG dereprication, quarity check, genomic analysis, and phylogenetic analysis
- HiFi read mapping on MAG/SAG
- Modification call and motif prediction
- defense system prediction
- Host-virus prediction

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

Also we used additional tools and databases for detailed data analysis in this study.
- [MEGA X](https://www.megasoftware.net/) - Phylogenetic tree analysis

## Usage 

TBA

## Citation 
1. Hiraoka S. in prep. 
2. Satoshi Hiraoka*, Tomomi Sumida, Miho Hirai, Atsushi Toyoda, Shinsuke Kawagucci, Taichi Yokokawa, Takuro Nunoura. Diverse DNA modification in marine prokaryotic and viral communities. Nucleic Acids Research. 50(3), 1531-1550. (2022)
   - https://academic.oup.com/nar/article/50/3/1531/6509096
   - First paper of the Metaepigenomic analysis of marine communities including prokaryotes and viruses. 
4. Satoshi Hiraoka*, Yusuke Okazaki, Mizue Anda, Atsushi Toyoda, Shin-ichi Nakano, Wataru Iwasaki*. Metaepigenomic analysis reveals the unexplored diversity of DNA methylations in an environmental prokaryotic community. Nature Communications. 10, 159. (2019)
   - https://www.nature.com/articles/s41467-018-08103-y
   - First paper of the Metaepigenomic analysis of prokaryotic communities. 
```
Email: hiraokas@jamstec.go.jp
```
