####################################################################################################
#
# script to create the tranch plot from GATK VQSR workflow
# extracted from GATK jar file and modified by marcin
#
# March, 2020
#
########################################################################## marcin.adamski@anu edu.au

library(tools)
rm(list=ls())

args <- commandArgs(TRUE)
verbose = TRUE

tranchesFile = args[1]
targetTITV = 2.15


#tranchesFile = "CCG38_cohort215.SNP.tranches"

# -----------------------------------------------------------------------------------------------
# Useful general routines
# -----------------------------------------------------------------------------------------------

MIN_FP_RATE = 0.001 # 1 / 1000 is min error rate 

titvFPEst <- function(titvExpected, titvObserved) { 
    max(min(1 - (titvObserved - 0.5) / (titvExpected - 0.5), 1), MIN_FP_RATE) 
}

titvFPEstV <- function(titvExpected, titvs) {
    sapply(titvs, function(x) titvFPEst(titvExpected, x))
}

nTPFP <- function(nVariants, FDR) {
    return(list(TP = nVariants * (1 - FDR/100), FP = nVariants * (FDR / 100)))
}

leftShift <- function(x, leftValue = 0) {
    r = rep(leftValue, length(x))
    for ( i in 1:(length(x)-1) ) {
        #print(list(i=i))
        r[i] = x[i+1]
    }
    r
}

# -----------------------------------------------------------------------------------------------
# Tranches plot
# -----------------------------------------------------------------------------------------------
data2 = read.table(tranchesFile,sep=",",head=T)
#data2 = data2[order(data2$novelTiTv, decreasing=F),]
data2 = data2[order(data2$minVQSLod, decreasing=F),]
#data2 = data2[order(data2$FDRtranche, decreasing=T),]
cols = c("cornflowerblue", "cornflowerblue", "darkorange", "darkorange")
density=c(20, -1, -1, 20)
outfile = paste(tranchesFile, ".png", sep="")
png(outfile, width = 900, height = 600, units = "px", pointsize = 20)
novelTiTv = c(data2$novelTITV,data2$novelTiTv)
alpha = 1 - titvFPEstV(targetTITV, novelTiTv)
#print(alpha)

numGood = round(alpha * data2$numNovel);

#numGood = round(data2$numNovel * (1-data2$targetTruthSensitivity/100))
numBad = data2$numNovel - numGood;

numPrevGood = leftShift(numGood, 0)
numNewGood = numGood - numPrevGood
numPrevBad = leftShift(numBad, 0)
numNewBad = numBad - numPrevBad

d = matrix(c(numPrevGood,numNewGood, numNewBad, numPrevBad),4,byrow=TRUE)

par(mar = c(4, 8.5, 4.5, 0.25) + 0.1, xpd = T)
barplot(d / 1000, horiz = TRUE, col = cols, space = 0.2, xlab = "Number of Novel Variants (1000s)", density = density, cex.axis = 1.0, cex.lab = 1.0)
title("Tranche Plot from GATK VQSR SNP", font.main = 1, cex.main = 1.0, line = -1.5, outer = T)
legend("topright", inset=c(0.10, -0.12), length(data2$targetTruthSensitivity) / 3 + 1, c('Cumulative TPs','Tranch-specific TPs', 'Tranch-specific FPs', 'Cumulative FPs' ), fill = cols, density = density, bg = 'white', cex = 0.75, ncol = 4)

mtext("minVQSLod", 2, line = 3.75, at = length(data2$targetTruthSensitivity) * 1.22, las = 1, cex = 1)
mtext("Sensitiv.", 2, line = 0, at = length(data2$targetTruthSensitivity) * 1.22, las = 1, cex = 1)
axis(2, line = -1, at = 0.7 + (0:(length(data2$targetTruthSensitivity) - 1)) * 1.2, tick = FALSE, labels=data2$targetTruthSensitivity, las = 1, cex.axis = 1.0)
axis(2, line = 3, at = 0.7 + (0:(length(data2$targetTruthSensitivity) - 1)) * 1.2, tick = FALSE, labels=round(data2$minVQSLod, 1), las = 1, cex.axis = 1.0)

dev.off()
