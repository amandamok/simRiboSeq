#!/bin/bash

### for simRiboviz.fq

# 1. trim adaptor
cutadapt -a CTGTAGGCACCATCAAT -o simRiboviz_trimmed.fq simRiboviz.fq \
    > simRiboviz_trimmed.cutadapt

# 2. align to transcriptome
bowtie-build yeast_YAL_CDS_w_250utrs.fa yeast_YAL_CDS_w_250utrs
bowtie -a --norc -v 2 -p 20 yeast_YAL_CDS_w_250utrs simRiboviz_trimmed.fq \
    > simRiboviz_footprints.bam 2> simRiboviz_footprints.bowtiestats

hisat2-build yeast_YAL_CDS_w_250utrs.fa yeast_YAL_CDS_w_250utrs
hisat2 -k 2 --no-spliced-alignment --rna-strandness F --no-unal \
	-x yeast_YAL_CDS_w_250utrs -S simRiboviz_footprints.sam -U simRiboviz_trimmed.fq

# 3. zip files for github
gzip -k simRiboviz.fq
gzip -k simRiboviz_footprints.bam
gzip -k simRiboviz_footprints.sam

### for tiny_2genes.fq

# 1. trim adaptor
cutadapt -a CTGTAGGCACCATCAAT -o tiny_2genes_trimmed.fq tiny_2genes.fq \
    > tiny_2genes_trimmed.cutadapt
    
# 2. align to transcriptome
hisat2-build tiny_2genes_20utrs.fa tiny_2genes_20utrs
hisat2 -k 2 --no-spliced-alignment --rna-strandness F --no-unal \
    -x tiny_2genes_20utrs -S tiny_2genes_footprints.sam -U tiny_2genes_trimmed.fq