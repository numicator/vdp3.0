####################################################################################################
#
# script to create population PCA plot from peddy results
# needs two tsv files with background and sample data created by step_reportsnv.pl
#
# March, 2020
#
########################################################################## marcin.adamski@anu edu.au
rm(list = ls())
args <- commandArgs(TRUE)
bkgfile  <- args[1]
smplfile <- args[2]

#bkgfile  <- "ccg_cohort0002.background_pca.tsv"
#smplfile <- "ccg_cohort0002.pca.tsv"

cat("bkgfile:", bkgfile, "\n")
cat("smplfile:", smplfile, "\n")

bkg  <- read.table(bkgfile, sep = "\t", header = F)
smpl <- read.table(smplfile, sep = "\t", header = F)

colnames(bkg)  <- c("pop", "pc1", "pc2", "pc3")
colnames(smpl) <- c("smpl", "pop", "pc1", "pc2", "pc3")
bkg$pop  <- factor(bkg$pop, levels = c(levels(bkg$pop), "UNKNOWN"))
smpl$pop <- factor(smpl$pop, levels = levels(bkg$pop))

labels <- as.character(smpl$smpl)
boxes  <- sapply(nchar(labels), function(n) paste(rep("\U2588", n), collapse = ""))

outfile <- gsub(".tsv", ".png", smplfile)
png(outfile, width = 900, height = 600, units = "px", pointsize = 24)

par(mfrow = c(1, 1))
par(mar = c(0, 0, 0, 0))
par(pty = "m")

pal <- palette(c("red", "blue", "green", "darkviolet", "orange", "gray"))
opal <- palette(adjustcolor(palette(), alpha.f = 0.25))

plot(c(bkg$pc1, smpl$pc1), c(bkg$pc2, smpl$pc2), col = bkg$pop, axes = F, xlab = "PC1", ylab = "PC2", pch = 20, cex = 1.2)
title("PCA Projection of The Cohort onto 1000 Genomes", font.main = 1, cex.main = 1.0, line = -1.5)
#axis(1, col = "grey", cex.axis = 0.8)
#axis(2, col = "grey", cex.axis = 0.8)
#box(col = "grey")
#grid(col = "lightgray")
palette(opal)
points(smpl$pc1, smpl$pc2, col = smpl$pop, pch = 20, cex = 2 )
points(smpl$pc1, smpl$pc2, col = smpl$pop, pch = 21, cex = 2 )
text(smpl$pc1, smpl$pc2, labels = boxes, cex = 0.8, pos = 4, font = 2, col = rgb(1, 1, 1, alpha = 0.65))
text(smpl$pc1, smpl$pc2, labels = labels, col = "black", cex = 0.8, pos = 4, font = 2)
legend('topright', legend = levels(bkg$pop), col = 1:length(bkg$pop), pt.cex = 1.4, cex = 0.8, pch = 20, ncol = 3, bty = "n", inset = c(0.05, 0.15))
cat("done\n")
dev.off()
