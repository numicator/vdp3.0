chr	chromosome
pos	start position of the variant
end	end position of the variant
event	type of the event (always <DEL>,<DUP>)
<SAMPLE>-GT	genotype of sample id <SAMPLE> (DEL, DUP or empty meaning reference)
<SAMPLE>-CN	copy number for sample id <SAMPLE>
<SAMPLE>-CNQ	genotype call quality for sample id <SAMPLE>
<SAMPLE>-CNLP	copy number log posterior in Phred-scale
Allele	always DEL,DUP
Consequence	consequence of the variant, see table 1
IMPACT	impact of the variant, see table 1 (do not use - currently it seems to apply to the beginning possition of the variant, not the whole interval)
SYMBOL	affected gene symbol (may be empty)
Gene	affected gene id (may be empty)
Feature_type	feature type (Transcript, RegulatoryFeature, MotifFeature)
Feature	Ensembl or RefSeq stable ID of feature
BIOTYPE	Biotype of transcript or regulatory feature
EXON	the affected exon number (out of total number)
INTRON	the affected intron number (out of total number)
HGVSc	HGVS coding sequence name (not used)
HGVSp	HGVS protein sequence name (not used)
cDNA_position	relative position of base pair in cDNA sequence (disregard)
CDS_position	relative position of base pair in coding sequence (disregard)
Protein_position	relative position of amino acid in protein (disregard)
Amino_acids	only given if the variant affects the protein-coding sequence (disregard)
Codons	the alternative codons with the variant base in upper case (disregard)
Existing_variation	known identifier of existing variant  (not used)
DISTANCE	shortest distance from the variant to transcript
STRAND	the DNA strand (1 or -1) on which the transcript/feature lies
PICK	indicates that this block of consequence data was picked (always 1)
SYMBOL_SOURCE	the source of the gene symbol
HGNC_ID	gene ID in HGNC database
CANONICAL	a flag indicating if the transcript is denoted as the canonical transcript for this gene
REFSEQ_MATCH	the RefSeq transcript match status (not used)
SOURCE	source of the annotation (Ensembl, RefSeq or empty)
GIVEN_REF	reference allele from input (technical check)
USED_REF	reference allele as used to get consequences (technical check)
BAM_EDIT	indicates success or failure of edit using BAM file (technical check)
HGVS_OFFSET	Indicates by how many bases the HGVS notations for this variant have been shifted
MOTIF_NAME	the source and identifier of a transcription factor binding profile aligned at this position
MOTIF_POS	the relative position of the variation in the aligned TFBP
HIGH_INF_POS	a flag indicating if the variant falls in a high information position of a transcription factor binding profile (TFBP)
MOTIF_SCORE_CHANGE	the difference in motif score of the reference and variant sequences for the TFBP
