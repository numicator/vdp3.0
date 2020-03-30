####################################################################################################
#
# script to create pedigree tree from PED file
# needs ped file
#
# the issue is that each offspring needs both parents present
# it would be necessary to generate artificial missing parents, maybe sometime later...
#
# March, 2020
#
########################################################################## marcin.adamski@anu edu.au
library(kinship2)

rm (list = ls())
args <- commandArgs(TRUE)
pedPath <- args[1]

#pedPath <- "../../CCG38_cohort215.ped"

pedfile <- read.table(pedPath, sep = "\t", header = F)
colnames(pedfile) <- c("family_id", "sample_id", "paternal_id", "moternal_id", "sex", "affected")
pedfile[pedfile$paternal_id == 0, ]$paternal_id <- NA
pedfile[pedfile$moternal_id == 0, ]$moternal_id <- NA

id       <- as.character(pedfile$sample_id)
dadid    <- as.character(pedfile$paternal_id)
momid    <- as.character(pedfile$moternal_id)
sex      <- as.numeric(pedfile$sex)
affected <- as.numeric(pedfile$affected)

ped <- pedigree(id = id, 
                dadid = dadid,
                momid = momid,
                sex   = sex,
                affected = affected
                )

opal <- palette(c("darkgreen", "red"))
plot.pedigree(ped, cex = 1.2, align = T, col = affected)
palette("default")
