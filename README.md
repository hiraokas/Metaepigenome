# Metaepigenome (under development)

Metaepigenomics is a powerful culture-independent method for revealing the epigenomic landscape of microbial communities. Here, we are developing a bioinformatic workflow for metaepigenomic analysis.
We are conducting a metaepigenomic analysis of thermophilic microbial samples and have provided the study scripts on this GitHub page.

Please note that the scripts were developed to analyze the original studies. This means that the scripts are not strictly concatenated as a stand-alone research pipeline and validated for other perspectives. The analysis has been performed on [the supercomputing system at National Institute of Genetics (NIG), Research Organization of Information and Systems (ROIS)](https://sc.ddbj.nig.ac.jp/en/), and [the Earth Simulator systems at JAMSTEC](https://www.jamstec.go.jp/es/en/).

The main script and related modules are stored in the src/ directory. 
The official source code repository is at https://github.com/hiraokas/Metaepigenome.

### Overview
<img width="821" height="489" alt="Metaepigenome_overview" src="https://github.com/user-attachments/assets/9b8f3d0d-5996-4dcd-8053-788e1eda7a31" />

### Main step
- Metagenome assembly and binning for MAG reconstruction
- Single-cell genome analysis for SAG reconstruction
- Virus and extrachromosomal circular genome extraction
- prokaryotic MAG/SAG dereplication, quality check, genomic analysis, and phylogenetic analysis
- HiFi read mapping on MAG/SAGs
- Modification call and motif prediction
- defense system prediction
- Host-virus prediction

## Code
The codes are written in shell script and Python.
The main script in this study is: mainScript_HotSpring.sh

## Used bioinformatic tools
- [Nonpareil3](https://github.com/lmrodriguezr/nonpareil) - Metagenomic coverage estimation.
- [Prodigal](https://github.com/hyattpd/Prodigal) - CDS prediction.
- [hifiasm-meta](https://github.com/lh3/hifiasm-meta) - Metagenomic assemgling.
- [hifiasm](https://github.com/chhylp123/hifiasm) - Genomic assemgling.
- [SPAdes](https://github.com/ablab/spades) - Genomic assemgling for single-cell.
- [pbmm2](https://github.com/PacificBiosciences/pbmm2) - HiFi read mapping.
- [CheckM2](https://github.com/chklovski/CheckM2) - Genome quality estimation for prokaryotes.
- [CheckV](https://bitbucket.org/berkeleylab/checkv/src/master/) - Genome quality estimation for viruses.
- [dRep](https://github.com/MrOlm/drep) - Genome dereplication for prokaryotes.
- [Galah](https://github.com/wwood/galah) - Genome dereplication for viruses and extrachromosomal circular genomes.
- [Kaiju](https://bioinformatics-centre.github.io/kaiju/) - Taxonomic assignment of HiFi reads.
- [GTDB-Tk](https://github.com/ecogenomics/gtdbtk) - Taxonomic assignment of prokaryotic genomes.
- [VITAP](https://github.com/DrKaiyangZheng/VITAP) - Taxonomic assignment of viral genomes.
- [DIAMOND](https://github.com/bbuchfink/diamond) - Protein similarity search.
- [SeqKit2](https://bioinf.shenwei.me/seqkit/) - Sequence manipulation.
- [MMseq2](https://github.com/soedinglab/MMseqs2) - Sequence clustering.
- [MAFFT](https://mafft.cbrc.jp/alignment/software/) - Multiple sequence alignment.
- [FastTree2](https://www.microbesonline.org/fasttree/) - Phylogenetic tree construction for prokaryotes.
- [ViPTreeGen](https://github.com/yosuken/ViPTreeGen) - Proteomic tree construction for viruses.
- [IGV](https://igv.org/) - Genome viewer.
- [PADLOC](https://padloc.otago.ac.nz/padloc/) - Defense system prediction.
- [iPhoP](https://bitbucket.org/srouxjgi/iphop/src/main/) - Host prediction.
<!-- 
- [Bowtie2](https://bowtie-bio.sourceforge.net/bowtie2/index.shtml) - Read mapping for short-read.
- [HMMER](http://hmmer.org/download.html) - HMM search. 
- [MEGA X](https://www.megasoftware.net/) - Phylogenetic tree analysis
-->

## Citation 
- Metaepigenome.
1. Hiraoka S. et al. in prep. 
2. Satoshi Hiraoka*, Tomomi Sumida, Miho Hirai, Atsushi Toyoda, Shinsuke Kawagucci, Taichi Yokokawa, Takuro Nunoura. Diverse DNA modification in marine prokaryotic and viral communities. Nucleic Acids Research. 50(3), 1531-1550. (2022)
   - https://academic.oup.com/nar/article/50/3/1531/6509096
   - First paper of the Metaepigenomic analysis of marine microbial communities including prokaryotes and viruses.
3. Satoshi Hiraoka*, Yusuke Okazaki, Mizue Anda, Atsushi Toyoda, Shin-ichi Nakano, Wataru Iwasaki*. Metaepigenomic analysis reveals the unexplored diversity of DNA methylations in an environmental prokaryotic community. Nature Communications. 10, 159. (2019)
   - https://www.nature.com/articles/s41467-018-08103-y
   - First proposed the concept of Metaepigenomics.
   - Conducted the metaepigenomic analysis of freshwater samples and analyzed prokaryotic communities, including both bacteria and archaea.
- Hot spring samples.
   - TAB
```
Contact:
Satoshi Hiraoka, Ph.D.
Bioresource Innovation Technology and Research Program (BITER), Institute for Extra-cutting-edge Science and Technology Avant-garde Research of Life (X-star), Japan Agency for Marine-Earth Science and Technology (JAMSTEC)
Email: hiraokas@jamstec.go.jp
HomePage: https://sites.google.com/site/shselfintro/
```
