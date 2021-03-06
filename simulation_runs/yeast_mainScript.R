rm(list=ls())

# load scripts ------------------------------------------------------------

library(parallel)

scriptDir <- "."
outputDir <- "../outputs"
refDir <- "../refData"

scripts <- c("helper.R", "simTranscriptome.R", "simRibosomeDist.R", "simFootprints.R")
for(x in scripts) {source(file.path(scriptDir, x))}

# reference data ----------------------------------------------------------

## general params:
codons <- apply(expand.grid(c("A", "T", "C", "G"),
                            c("A", "T", "C", "G"),
                            c("A", "T", "C", "G")),
                1, paste, collapse="")
# simTranscriptome()
uniformCodonDist <- rep(1, length(codons))/length(codons)
names(uniformCodonDist) <- codons
# digest()
delta5_uniform <- rep(1, 3)/3
names(delta5_uniform) <- as.character(15:17)
delta3_uniform <- rep(1, 3)/3
names(delta3_uniform) <- as.character(9:11)
minSize <- 27
maxSize <- 31
# nReads_weinberg <- 72928017
# nReads_green <- 55018963
# nReads_lareau <- 85607480
nReads <- 8e7
partSize <- 1e6
nParts <- nReads/partSize

## yeast genome params for simTranscriptome()
yeastFAfile <- "scer.transcripts.13cds10.fa"
yeast_pad5 <- 13
yeast_pad3 <- 10
yeastFAlist <- readFAfile(file.path(refDir, yeastFAfile), 
                          yeast_pad5, yeast_pad3)
# filter out transcripts w/ < 20 codons + padding
yeastFAlist <- yeastFAlist[lengths(yeastFAlist) > (yeast_pad5+yeast_pad3+20)] 
yeastLengths <- lengths(yeastFAlist) - floor(yeast_pad5/3) - floor(yeast_pad3/3)
yeastCodonCounts <- countCodons(yeastFAlist, codons, yeast_pad5, yeast_pad3)
yeastCodonDist <- rowSums(yeastCodonCounts)/sum(yeastCodonCounts)
rm(yeastFAlist)

## weinberg expt: gene lengths and abundances for simPi()
weinberg_file <- "cts_by_codon.size.27.31.txt"
weinberg_data <- readRawProfiles(file.path(refDir, weinberg_file))
weinberg_lengths <- lengths(weinberg_data)
weinberg_abundances <- sapply(weinberg_data, sum)
weinberg_nRibosomes <- sum(weinberg_abundances)
rm(weinberg_data)

## weinberg expt: codon TE scores for simRho()
weinberg_codonTEfile <- "tunney_supp_table_2_codon_scores.csv"
weinberg_codonScores <- read.csv(file.path(refDir, weinberg_codonTEfile), 
                                 header=T, stringsAsFactors=F)
weinberg_codonTE <- weinberg_codonScores$X0
weinberg_codonTE <- weinberg_codonTE - min(weinberg_codonTE) # scale up so min = 0.1
weinberg_stopCodons <- codons[which(!(codons %in% weinberg_codonScores$codon))]
weinberg_codonTE <- c(weinberg_codonTE, rep(0, length(weinberg_stopCodons))) # add TE for stop codons
names(weinberg_codonTE) <- c(weinberg_codonScores$codon, weinberg_stopCodons)

## green expt: bias scores for ligate() & circularize()
# /mnt/lareaulab/rtunney/iXnos/results/green/s28_cod_n5p4_nt_n15p14/epoch30/codon_scores.tsv
green_biasFile <- "codon_scores.tsv"
green_biasScores <- read.table(file.path(refDir, green_biasFile))
colnames(green_biasScores) <- as.character(seq.int(from=-5, length.out=ncol(green_biasScores)))
green_p5bias <- exp(green_biasScores[,"-5"])
names(green_p5bias) <- sort(codons)
green_p5bias <- green_p5bias/max(green_p5bias, na.rm=T)
# green_p5bias <- green_biasScores[,"-5"]
# green_p5bias <- (green_p5bias+1)/(max(green_p5bias, na.rm=T)+1)
green_p5bias[is.na(green_p5bias)] <- 0
green_n3bias <- exp(green_biasScores[,"3"])
names(green_n3bias) <- sort(codons)
green_n3bias <- green_n3bias/max(green_n3bias, na.rm=T)
# green_n3bias <- green_biasScores[,"3"]
# green_n3bias <- (green_n3bias+1)/(max(green_n3bias, na.rm=T)+1)
green_n3bias[is.na(green_n3bias)] <- 0
par(mfrow=c(2,1))
plot(density(green_biasScores[,"-5"], na.rm=T), main="p5 bias scores from green iXnos")
plot(density(green_p5bias), main="scaled p5 probabilities")
plot(density(green_biasScores[,"3"], na.rm=T), main="n3 bias scores from green iXnos")
plot(density(green_n3bias), main="scaled n3 probabilities")

## bias scores for ligate() & circularize() --> uniform bias
p5bias <- rep(1, length(codons))
names(p5bias) <- codons
n3bias <- rep(1, length(codons))
names(n3bias) <- codons

# simulation 1 ------------------------------------------------------------

### yeast, uniform codon distribution, uniform deltas, no bias

set.seed(99)

# 1. simulate transcriptome
# yeast genome
# uniform codon distribution
yeast_uniform <- simTranscriptome(yeastLengths, uniformCodonDist)
yeast_uniform <- yeast_uniform[lengths(yeast_uniform)>200]
writeTranscriptomeFA(yeast_uniform, 
                     file.path(outputDir, "yeast_uniformCodons.fa"))

# 2. simulate ribosome distributions
# weinberg data for expt lengths, abundances, codon TE
yeast_uniform_rho <- simRho(yeast_uniform, 
                            exptLengths=weinberg_lengths, 
                            exptAbundances=weinberg_abundances)
yeast_uniform_pi <- simPi(yeast_uniform,
                          codonTE=weinberg_codonTE)
save(yeast_uniform_rho, yeast_uniform_pi, 
     file=file.path(outputDir, "yeast_uniformCodons_rho_pi.Rda"))

# 3. simulate footprints
# uniform delta5, delta3
# minSize=27, maxSize=31
# no biases for ligBias (3') and circBias (5')

for(i in 1:nParts) {
  print(paste("Part", i, "of", nParts))
  partName <- paste0("yeast_uniform_uniform_noBias_part", i)
  part_filename <- paste0("yeast_uniformCodons_uniformDelta_noBias_80Mreads_part", i)
  assign(partName, 
         value=simFootprints(yeast_uniform, nRibosomes=partSize, 
                             rhos=yeast_uniform_rho, pis=yeast_uniform_pi,
                             delta5=delta5_uniform, delta3=delta3_uniform,
                             ligBias=n3bias, circBias=p5bias,
                             digest_transcript=digest_transcript))
  writeFootprintsFA(get(partName),
                    file.path(outputDir, paste0(part_filename, ".fa")))
  save(list=partName, 
       file=file.path(outputDir, paste0(part_filename, ".Rda")))
  rm(list=partName)
}

# simulation 2 ------------------------------------------------------------

### yeast, uniform codon distribution, uniform deltas, green bias

set.seed(72)

# 3. simulate footprints
# uniform delta5, delta3
# minSize=27, maxSize=31
# green data for ligBias (3') and circBias (5')

for(i in 1:nParts) {
  print(paste("Part", i, "of", nParts))
  partName <- paste0("yeast_uniform_uniform_withBias_part", i)
  part_filename <- paste0("yeast_uniformCodons_uniformDelta_withBias_80Mreads_part", i)
  assign(partName, 
         value=simFootprints(yeast_uniform, nRibosomes=partSize, 
                             rhos=yeast_uniform_rho, pis=yeast_uniform_pi,
                             delta5=delta5_uniform, delta3=delta3_uniform,
                             ligBias=green_n3bias, circBias=green_p5bias,
                             digest_transcript=digest_transcript))
  writeFootprintsFA(get(partName),
                    file.path(outputDir, paste0(part_filename, ".fa")))
  save(list=partName, 
       file=file.path(outputDir, paste0(part_filename, ".Rda")))
  rm(list=partName)
}

# simulation 3 ------------------------------------------------------------

### yeast, yeast codon distribution, uniform deltas, no bias

set.seed(35)

# 1. simulate transcriptome
# yeast genome
# yeast codon distribution
yeast_yeast <- simTranscriptome(yeastLengths, yeastCodonDist)
yeast_yeast <- yeast_yeast[lengths(yeast_yeast)>200]
writeTranscriptomeFA(yeast_yeast, 
                     file.path(outputDir, "yeast_yeastCodons.fa"))

# 2. simulate ribosome distributions
# weinberg data for expt lengths, abundances, codon TE
yeast_yeast_rho <- simRho(yeast_yeast, 
                            exptLengths=weinberg_lengths, 
                            exptAbundances=weinberg_abundances)
yeast_yeast_pi <- simPi(yeast_yeast,
                          codonTE=weinberg_codonTE)
save(yeast_yeast_rho, yeast_yeast_pi, 
     file=file.path(outputDir, "yeast_yeastCodons_rho_pi.Rda"))

# 3. simulate footprints
# uniform delta5, delta3
# minSize=27, maxSize=31
# no biases for ligBias (3') and circBias (5')

for(i in 1:nParts) {
  print(paste("Part", i, "of", nParts))
  partName <- paste0("yeast_yeast_uniform_noBias_part", i)
  part_filename <- paste0("yeast_yeastCodons_uniformDelta_noBias_80Mreads_part", i)
  assign(partName, 
         value=simFootprints(yeast_yeast, nRibosomes=partSize, 
                             rhos=yeast_yeast_rho, pis=yeast_yeast_pi,
                             delta5=delta5_uniform, delta3=delta3_uniform,
                             ligBias=n3bias, circBias=p5bias,
                             digest_transcript=digest_transcript))
  writeFootprintsFA(get(partName),
                    file.path(outputDir, paste0(part_filename, ".fa")))
  save(list=partName, 
       file=file.path(outputDir, paste0(part_filename, ".Rda")))
  rm(list=partName)
}

# simulation 4 ------------------------------------------------------------

### yeast, yeast codon distribution, uniform deltas, with bias

set.seed(17)

# 3. simulate footprints
# uniform delta5, delta3
# minSize=27, maxSize=31
# green data for ligBias (3') and circBias (5')

for(i in 1:nParts) {
  print(paste("Part", i, "of", nParts))
  partName <- paste0("yeast_yeast_uniform_withBias_part", i)
  part_filename <- paste0("yeast_yeastCodons_uniformDelta_withBias_80Mreads_part", i)
  assign(partName, 
         value=simFootprints(yeast_yeast, nRibosomes=partSize, 
                             rhos=yeast_yeast_rho, pis=yeast_yeast_pi,
                             delta5=delta5_uniform, delta3=delta3_uniform,
                             ligBias=green_n3bias, circBias=green_p5bias,
                             digest_transcript=digest_transcript))
  writeFootprintsFA(get(partName),
                    file.path(outputDir, paste0(part_filename, ".fa")))
  save(list=partName, 
       file=file.path(outputDir, paste0(part_filename, ".Rda")))
  rm(list=partName)
}