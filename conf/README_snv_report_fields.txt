chr	chromosome
pos	start position of the variant
ref	reference allele
alt	variant allele
FILTER	filter applied (ok, RD_CVR<5)
RD	read coverage, number of reads at locus (AD0 + AD1)
AD0	number of reads supporting reference allele
AD1	number of reads supporting variant allele
<SAMPLE>-GT	genotype of sample id <SAMPLE>
<SAMPLE>-GQ	quality of genotyping of sample id <SAMPLE>
<SAMPLE>-RD	read coverage, number of reads at locus (<SAMPLE>-AD0 + <SAMPLE>-AD1) for sample id <SAMPLE>
<SAMPLE>-AD0	number of reads supporting reference allele for sample id <SAMPLE>
<SAMPLE>-AD1	number of reads supporting variant allele for sample id <SAMPLE>
caller	variant caller which called the variant (gatk_hc, strelka, varscan, strelka+varscan)
VQSLOD	Variant Quality Score Log-Odds for variants called with gatk_hc
MQ	Map Quality for variants called with gatk_hc and strelka
Allele	the variant allele used to calculate the consequence
Consequence	consequence of the variant, see table 1
IMPACT	impact of the variant, see table 1
SYMBOL	affected gene symbol (may be empty)
Gene	affected gene id (may be empty)
Feature_type	feature type (Transcript, RegulatoryFeature, MotifFeature)
Feature	Ensembl or RefSeq stable ID of feature
BIOTYPE	Biotype of transcript or regulatory feature
EXON	the exon number (out of total number)
INTRON	the intron number (out of total number)
HGVSc	HGVS coding sequence name
HGVSp	HGVS protein sequence name
cDNA_position	relative position of base pair in cDNA sequence
CDS_position	relative position of base pair in coding sequence
Protein_position	relative position of amino acid in protein
Amino_acids	only given if the variant affects the protein-coding sequence
Codons	the alternative codons with the variant base in upper case
Existing_variation	known identifier of existing variant (rs-<number>,COSV-<number>)
DISTANCE	shortest distance from the variant to transcript
STRAND	the DNA strand (1 or -1) on which the transcript/feature lies
FLAGS	transcript quality flags: cds_start_NF - CDS 5' incomplete, cds_end_NF - CDS 3' incomplete (in most cases empty)
PICK	indicates that this block of consequence data was picked (always 1)
SYMBOL_SOURCE	the source of the gene symbol
HGNC_ID	gene ID in HGNC database
CANONICAL	a flag indicating if the transcript is denoted as the canonical transcript for this gene
REFSEQ_MATCH	the RefSeq transcript match status (not used)
SOURCE	source of the annotation (Ensembl, RefSeq or empty)
GIVEN_REF	reference allele from input (technical check)
USED_REF	reference allele as used to get consequences (technical check)
BAM_EDIT	indicates success or failure of edit using BAM file (technical check)
SIFT	the SIFT prediction and score, with both given as prediction(score)
PolyPhen	the PolyPhen prediction and score
DOMAINS	the source and identifer of any overlapping protein domains
HGVS_OFFSET	Indicates by how many bases the HGVS notations for this variant have been shifted
AF	frequency of existing variant in 1000 Genomes
gnomAD_AF	frequency of existing variant in gnomAD 2.1 exomes combined population
gnomAD_AFR_AF	frequency of existing variant in gnomAD 2.1 exomes African/American population population
gnomAD_AMR_AF	frequency of existing variant in gnomAD 2.1 exomes American population population
gnomAD_ASJ_AF	frequency of existing variant in gnomAD 2.1 exomes Ashkenazi Jewish population
gnomAD_EAS_AF	frequency of existing variant in gnomAD 2.1 exomes East Asian population
gnomAD_FIN_AF	frequency of existing variant in gnomAD 2.1 exomes Finnish population
gnomAD_NFE_AF	frequency of existing variant in gnomAD 2.1 exomes Non-Finnish European population
gnomAD_OTH_AF	frequency of existing variant in gnomAD 2.1 exomes other combined population
gnomAD_SAS_AF	frequency of existing variant in gnomAD 2.1 exomes South Asian population
CLIN_SIG	ClinVar clinical significance of the dbSNP variant
SOMATIC	somatic status of existing variant(s); multiple values correspond to multiple values in the Existing_variation field
PHENO	indicates if existing variant is associated with a phenotype, disease or trait
PUBMED	Pubmed ID(s) of publications that cite existing variant
MOTIF_NAME	the source and identifier of a transcription factor binding profile aligned at this position
MOTIF_POS	the relative position of the variation in the aligned TFBP
HIGH_INF_POS	a flag indicating if the variant falls in a high information position of a transcription factor binding profile (TFBP)
MOTIF_SCORE_CHANGE	the difference in motif score of the reference and variant sequences for the TFBP
SpliceRegion	affected splice region (splice_donor_5th_base_variant, splice_donor_region_variant, splice_donor_region_variant, splice_polypyrimidine_tract_variant, splice_polypyrimidine_tract_variant)
CADD_PHRED	PHRED-like scaled CADD score (Combined Annotation Dependent Depletion)
CADD_RAW	Raw CADD score
ClinVar	Clinvar variation id
ClinVar_CLNSIG	ClinVar clinical significance of the variant
ClinVar_CLNREVSTAT	ClinVar review status for the variation
ClinVar_CLNDN	ClinVar disease name for an interpretation for a haplotype or genotype that includes this variant
gnomAD3	variant id in gnomAD 3
gnomAD3_AF	frequency gnomAD 3 genomes combined population
gnomAD3_AF_female	frequency gnomAD 3 genomes combined female population
gnomAD3_AF_male	frequency gnomAD 3 genomes combined male population
gnomAD3_AF_afr	frequency gnomAD 3 genomes African population
gnomAD3_AF_afr_female	frequency gnomAD 3 genomes African female population
gnomAD3_AF_afr_male	frequency gnomAD 3 genomes African male population
gnomAD3_AF_ami	frequency gnomAD 3 genomes Amish population
gnomAD3_AF_ami_female	frequency gnomAD 3 genomes Amish female population
gnomAD3_AF_ami_male	frequency gnomAD 3 genomes Amish male population
gnomAD3_AF_amr	frequency gnomAD 3 genomes American population
gnomAD3_AF_amr_female	frequency gnomAD 3 genomes American female population
gnomAD3_AF_amr_male	frequency gnomAD 3 genomes American male population
gnomAD3_AF_asj	frequency gnomAD 3 genomes Ashkenazi Jewish population
gnomAD3_AF_asj_female	frequency gnomAD 3 genomes Ashkenazi Jewish female population
gnomAD3_AF_asj_male	frequency gnomAD 3 genomes Ashkenazi Jewish male population
gnomAD3_AF_eas	frequency gnomAD 3 genomes East Asian population
gnomAD3_AF_eas_female	frequency gnomAD 3 genomes East Asian female population
gnomAD3_AF_eas_male	frequency gnomAD 3 genomes East Asian male population
gnomAD3_AF_fin	frequency gnomAD 3 genomes Finnish population
gnomAD3_AF_fin_female	frequency gnomAD 3 genomes Finnish female population
gnomAD3_AF_fin_male	frequency gnomAD 3 genomes Finnish male population
gnomAD3_AF_nfe	frequency gnomAD 3 genomes Non-Finnish European population
gnomAD3_AF_nfe_female	frequency gnomAD 3 genomes Non-Finnish European female population
gnomAD3_AF_nfe_male	frequency gnomAD 3 genomes Non-Finnish European male population
gnomAD3_AF_sas	frequency gnomAD 3 genomes South Asian population
gnomAD3_AF_sas_female	frequency gnomAD 3 genomes South Asian female population
gnomAD3_AF_sas_male	frequency gnomAD 3 genomes South Asian male population
gnomAD3_AF_oth	frequency gnomAD 3 genomes other combined population
gnomAD3_AF_oth_female	frequency gnomAD 3 genomes other combined female population
gnomAD3_AF_oth_male	frequency gnomAD 3 genomes other combined male population




Table 1: Consequene and Impact terms of variants (defined by Sequence Ontolgy, SO)
Consequene term	SO description	SO accession	Display term	IMPACT
transcript_ablation	A feature ablation whereby the deleted region includes a transcript feature	SO:0001893	Transcript ablation	HIGH
splice_acceptor_variant	A splice variant that changes the 2 base region at the 3' end of an intron	SO:0001574	Splice acceptor variant	HIGH
splice_donor_variant	A splice variant that changes the 2 base region at the 5' end of an intron	SO:0001575	Splice donor variant	HIGH
stop_gained	A sequence variant whereby at least one base of a codon is changed, resulting in a premature stop codon, leading to a shortened transcript	SO:0001587	Stop gained	HIGH
frameshift_variant	A sequence variant which causes a disruption of the translational reading frame, because the number of nucleotides inserted or deleted is not a multiple of three	SO:0001589	Frameshift variant	HIGH
stop_lost	A sequence variant where at least one base of the terminator codon (stop) is changed, resulting in an elongated transcript	SO:0001578	Stop lost	HIGH
start_lost	A codon variant that changes at least one base of the canonical start codon	SO:0002012	Start lost	HIGH
transcript_amplification	A feature amplification of a region containing a transcript	SO:0001889	Transcript amplification	HIGH
inframe_insertion	An inframe non synonymous variant that inserts bases into in the coding sequence	SO:0001821	Inframe insertion	MODERATE
inframe_deletion	An inframe non synonymous variant that deletes bases from the coding sequence	SO:0001822	Inframe deletion	MODERATE
missense_variant	A sequence variant, that changes one or more bases, resulting in a different amino acid sequence but where the length is preserved	SO:0001583	Missense variant	MODERATE
protein_altering_variant	A sequence_variant which is predicted to change the protein encoded in the coding sequence	SO:0001818	Protein altering variant	MODERATE
splice_region_variant	A sequence variant in which a change has occurred within the region of the splice site, either within 1-3 bases of the exon or 3-8 bases of the intron	SO:0001630	Splice region variant	LOW
incomplete_terminal_codon_variant	A sequence variant where at least one base of the final codon of an incompletely annotated transcript is changed	SO:0001626	Incomplete terminal codon variant	LOW
start_retained_variant	A sequence variant where at least one base in the start codon is changed, but the start remains	SO:0002019	Start retained variant	LOW
stop_retained_variant	A sequence variant where at least one base in the terminator codon is changed, but the terminator remains	SO:0001567	Stop retained variant	LOW
synonymous_variant	A sequence variant where there is no resulting change to the encoded amino acid	SO:0001819	Synonymous variant	LOW
coding_sequence_variant	A sequence variant that changes the coding sequence	SO:0001580	Coding sequence variant	MODIFIER
mature_miRNA_variant	A transcript variant located with the sequence of the mature miRNA	SO:0001620	Mature miRNA variant	MODIFIER
5_prime_UTR_variant	A UTR variant of the 5' UTR	SO:0001623	5 prime UTR variant	MODIFIER
3_prime_UTR_variant	A UTR variant of the 3' UTR	SO:0001624	3 prime UTR variant	MODIFIER
non_coding_transcript_exon_variant	A sequence variant that changes non-coding exon sequence in a non-coding transcript	SO:0001792	Non coding transcript exon variant	MODIFIER
intron_variant	A transcript variant occurring within an intron	SO:0001627	Intron variant	MODIFIER
NMD_transcript_variant	A variant in a transcript that is the target of NMD	SO:0001621	NMD transcript variant	MODIFIER
non_coding_transcript_variant	A transcript variant of a non coding RNA gene	SO:0001619	Non coding transcript variant	MODIFIER
upstream_gene_variant	A sequence variant located 5' of a gene	SO:0001631	Upstream gene variant	MODIFIER
downstream_gene_variant	A sequence variant located 3' of a gene	SO:0001632	Downstream gene variant	MODIFIER
TFBS_ablation	A feature ablation whereby the deleted region includes a transcription factor binding site	SO:0001895	TFBS ablation	MODIFIER
TFBS_amplification	A feature amplification of a region containing a transcription factor binding site	SO:0001892	TFBS amplification	MODIFIER
TF_binding_site_variant	A sequence variant located within a transcription factor binding site	SO:0001782	TF binding site variant	MODIFIER
regulatory_region_ablation	A feature ablation whereby the deleted region includes a regulatory region	SO:0001894	Regulatory region ablation	MODERATE
regulatory_region_amplification	A feature amplification of a region containing a regulatory region	SO:0001891	Regulatory region amplification	MODIFIER
feature_elongation	A sequence variant that causes the extension of a genomic feature, with regard to the reference sequence	SO:0001907	Feature elongation	MODIFIER
regulatory_region_variant	A sequence variant located within a regulatory region	SO:0001566	Regulatory region variant	MODIFIER
feature_truncation	A sequence variant that causes the reduction of a genomic feature, with regard to the reference sequence	SO:0001906	Feature truncation	MODIFIER
intergenic_variant	A sequence variant located in the intergenic region, between genes	SO:0001628	Intergenic variant	MODIFIER