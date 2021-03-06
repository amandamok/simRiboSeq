rm(list=ls())

library(parallel)
library(here)

# load scripts ------------------------------------------------------------

script_dir <- file.path(here(), "scripts")
ref_dir <- file.path(here(), "refData")
output_dir <- "."

scripts <- c("helper.R", "simTranscriptome.R", "simRibosomeDist.R", "simFootprints.R")
for(x in scripts) {source(file.path(script_dir, x))}

# reference data ----------------------------------------------------------

## general params:
codons <- apply(expand.grid(c("A", "T", "C", "G"),
                            c("A", "T", "C", "G"),
                            c("A", "T", "C", "G")),
                1, paste, collapse="")
delta5_bias <- c(0.4, 0.3, 0.2)
names(delta5_bias) <- as.character(15:17)
delta3_bias <- c(0.35, 0.4, 0.25)
names(delta3_bias) <- as.character(9:11)
minSize <- 27
maxSize <- 31
nReads <- 10
# partSize <- 1e6
# nParts <- nReads/partSize

## weinberg expt: gene lengths and abundances for simRho()
weinberg_file <- "cts_by_codon.size.27.31.txt"
weinberg_data <- readRawProfiles(file.path(ref_dir, weinberg_file))
weinberg_lengths <- lengths(weinberg_data)
weinberg_abundances <- sapply(weinberg_data, sum)
weinberg_nRibosomes <- sum(weinberg_abundances)
rm(weinberg_data)

## weinberg expt: codon TE scores for simPi()
weinberg_codonTEfile <- "tunney_supp_table_2_codon_scores.csv"
weinberg_codonScores <- read.csv(file.path(ref_dir, weinberg_codonTEfile), header=T, stringsAsFactors=F)
weinberg_codonTE <- weinberg_codonScores$X0
weinberg_codonTE <- weinberg_codonTE - min(weinberg_codonTE) # scale up so min = 0.1
weinberg_stopCodons <- codons[which(!(codons %in% weinberg_codonScores$codon))]
weinberg_codonTE <- c(weinberg_codonTE, rep(0, length(weinberg_stopCodons))) # add TE for stop codons
names(weinberg_codonTE) <- c(weinberg_codonScores$codon, weinberg_stopCodons)

## green expt: bias scores for ligate() & circularize()
# /mnt/lareaulab/rtunney/iXnos/results/green/s28_cod_n5p4_nt_n15p14/epoch30/codon_scores.tsv
bias_seq_2nt <- unique(substr(codons, start=1, stop=2))
green_biasFile <- "codon_scores.tsv"
green_biasScores <- read.table(file.path(ref_dir, green_biasFile))
colnames(green_biasScores) <- as.character(seq.int(from=-5, length.out=ncol(green_biasScores)))
# 5' bias probabilities
green_p5bias <- exp(green_biasScores[,"-5"])
green_p5bias <- green_p5bias/max(green_p5bias, na.rm=T)
green_p5bias[is.na(green_p5bias)] <- 0
names(green_p5bias) <- sort(codons)
green_p5bias_2nt <- sapply(bias_seq_2nt,
                           function(x) {
                             mean(green_p5bias[substr(names(green_p5bias), start=1, stop=2)==x])
                           })
green_p5bias_2nt[green_p5bias_2nt==0] <- 0.01
# 3' bias probabilities
green_n3bias <- exp(green_biasScores[,"3"])
green_n3bias <- green_n3bias/max(green_n3bias, na.rm=T)
green_n3bias[is.na(green_n3bias)] <- 0
names(green_n3bias) <- sort(codons)
green_n3bias_3nt <- green_n3bias
green_n3bias_3nt[green_n3bias_3nt==0] <- 0.01
# no bias (uniform bias)
no_p5bias <- rep(1, length(green_p5bias_2nt))
names(no_p5bias) <- names(green_p5bias_2nt)
no_n3bias <- rep(1, length(codons))
names(no_n3bias) <- codons

## non-templated base
noRTbias <- c(1, 0, 0, 0, 0)
names(noRTbias) <- c("", "A", "T", "C", "G")

# generate ribosome profiles ----------------------------------------------

# generate transcriptome: s. cerevisiae
tiny_2genes_file <- "tiny_2genes_20utrs.fa"
tiny_2genes <- readFAfile(tiny_2genes_file, pad5=20, pad3=20)

# simulate ribosome distributions
## weinberg data for expt lengths, abundances, codon TE
tiny_2genes_rho <- c(0.5, 0.5)
names(tiny_2genes_rho) <- names(tiny_2genes)
tiny_2genes_pi <- simPi(tiny_2genes, codonTE=weinberg_codonTE, pad5=6, pad3=7)

# simulate data: no bias --------------------------------------------------

# biased delta5, delta3
# minSize=27, maxSize=31
# 5' bias: green_p5bias_2nt
# 3' bias: green_n3bias_3nt
# no extra base: noRTbias

footprints <- simFootprints(tiny_2genes, nRibosomes=nReads,
                            rhos=tiny_2genes_rho, pis=tiny_2genes_pi,
                            delta5=delta5_bias, delta3=delta3_bias,
                            ligBias=green_n3bias_3nt, RTBias=noRTbias, circBias=green_p5bias_2nt,
                            digest_transcript=digest_transcript, mc.cores=1)
writeFootprintsFQ(footprints, file.path(output_dir, "tiny_2genes.fq"))

# pull out footprint statistics -------------------------------------------

d5_to_frame <- c(0, 2, 1)
names(d5_to_frame) <- names(delta5_bias)

fp_stats <- data.frame(t(sapply(footprints,
                                function(x) {
                                  c("transcript"=x@transcript,
                                    cod_idx=x@ASite+1,
                                    length=x@digest5+x@digest3+3,
                                    d5=x@digest5,
                                    d3=x@digest3,
                                    frame=d5_to_frame[as.character(x@digest5)])
                                })))
rownames(fp_stats) <- NULL

# aggregate footprints
fp_stats$cod_idx <- as.numeric(as.character(fp_stats$cod_idx))
fp_stats$length <- as.numeric(as.character(fp_stats$length))
colnames(fp_stats)[grepl("frame", colnames(fp_stats))] <- "frame"
fp_stats$frame <- as.numeric(as.character(fp_stats$frame))
fp_stats$cts <- 1
fp_stats <- aggregate(cts ~ frame + length + cod_idx + transcript, data=fp_stats, FUN=sum)
fp_stats <- fp_stats[, c("transcript", "cod_idx", "length", "frame", "cts")]

write.table(fp_stats, file="tiny_2genes_counts.tsv",
            quote=F, row.names=F, col.names=T, sep="\t")

# save and quit -----------------------------------------------------------

save(tiny_2genes_rho, tiny_2genes_pi, file=file.path(output_dir, "tiny_2genes_rho_pi.Rda"))
save(footprints, file=file.path(output_dir, "tiny_2genes_footprints.Rda"))

q(save="no")