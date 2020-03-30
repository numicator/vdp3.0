#Things to read:
https://www.nature.com/articles/s41598-019-45835-3
https://www.intechopen.com/books/bioinformatics-tools-for-detection-and-clinical-interpretation-of-genomic-variations/bioinformatics-workflows-for-genomic-variant-discovery-interpretation-and-prioritization
VariantRecalibration must be done on a complete genome, not on splits. Even non-split WES (or three of them) is actually too small dataset for VQSR to properly calibrate its models. Splitting it is a no-go.
ApplyVQSR may NOT be done on slplits. e.g. here: https://gatkforums.broadinstitute.org/gatk/discussion/23216/how-to-filter-variants-either-with-vqsr-or-by-hard-filtering 
https://gatk.broadinstitute.org/hc/en-us/articles/360035531112?id=2806 - crucial read on GATK variant filtering
http://www.ensembl.info/2018/06/22/cool-stuff-the-vep-can-do-normalisation/

while :; do ps -Ao %cpu,%mem|tail -n +1|awk 'BEGIN{cpu=0;mem=0} {cpu+=$1;mem+=$2} END{print cpu, mem}'; sleep 2; done &

#BWA
#https://github.com/lh3/bwa/releases
wget wget https://github.com/lh3/bwa/releases/download/v0.7.17/bwa-0.7.17.tar.bz2
tar xvf bwa-0.7.17.tar.bz2
cd bwa-0.7.17
make
./bwa

#picard
#https://github.com/broadinstitute/picard/release
wget https://github.com/broadinstitute/picard/releases/download/2.22.0/picard.jar

#GATK4
#https://github.com/broadinstitute/gatk/releases
wget https://github.com/broadinstitute/gatk/releases/download/4.1.5.0/gatk-4.1.5.0.zip

#GATK3
https://gatkforums.broadinstitute.org/gatk/discussion/10328/combinevariants-in-gatk4
wget https://storage.cloud.google.com/gatk-software/package-archive/gatk/GenomeAnalysisTK-3.8-1-0-gf15c1c3ef.tar.bz2
needs java: "1.8.0_40"; module load java/jdk-8.40

#Varscan
#https://github.com/dkoboldt/varscan
wget https://github.com/dkoboldt/varscan/blob/master/VarScan.v2.4.4.jar

#Strelka
#https://github.com/Illumina/strelka/releases
wget https://github.com/Illumina/strelka/releases/download/v2.9.10/strelka-2.9.10.centos6_x86_64.tar.bz2

#samtools/bcftools
wget https://github.com/samtools/samtools/releases/download/1.10/samtools-1.10.tar.bz2
wget https://github.com/samtools/bcftools/releases/download/1.10.2/bcftools-1.10.2.tar.bz2
wget https://github.com/samtools/htslib/releases/download/1.10.2/htslib-1.10.2.tar.bz2
for each: ./configure && make 

#bedtools
wget https://github.com/arq5x/bedtools2/releases/download/v2.29.2/bedtools-2.29.2.tar.gz
make

#R packages
module load intel-compiler/2020.0.166 #to get the compiler necessary for building modules
module load R/3.6.1 #to get R
mkdir -p <software>/R/3.6/lib
R
install.packages("ggplot2", lib="<software>/R/3.6/lib")
#to be able to use installed packages in jobs put into qsub file:
module load R/3.6.1
export R_LIBS_USER=<software>/R/3.6/lib

#VEP
https://github.com/Ensembl/ensembl-vep/archive/release/99.2.tar.gz
mkdir -p homo_sapiens/dna
cd homo_sapiens/dna
wget ftp://ftp.ensembl.org/pub/release-99/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
cd ..
wget ftp://ftp.ensembl.org/pub/release-99/variation/vep/homo_sapiens_vep_99_GRCh38.tar.gz
wget ftp://ftp.ensembl.org/pub/release-99/variation/vep/homo_sapiens_merged_vep_99_GRCh38.tar.gz

#install cpanm in software/perl5
#from software directory run:
curl -L http://cpanmin.us | perl - -l perl5 App::cpanminus local::lib
alias cpanm="/g/data/xx92/vdp3.0/software/perl5/bin/cpanm -l /g/data/xx92/vdp3.0/software/perl5 -L /g/data/xx92/vdp3.0/software/perl5"
#modules needed by ensembl-vep:
cpanm DBD::mysql
cpanm JSON
cpanm PerlIO::gzip
cpanm Try::Tiny

cpanm Module::Install
cpanm PDF::API2
cpanm PDF::API2::Simple
cpanm PDF::Table

#installation script will need to have bgzip and tabix in search path
./INSTALL.pl --CACHEDIR /g/data/xx92/vdp3.0/GRCh38/vep_index/ --CONVERT --CACHEURL /g/data/xx92/vdp3.0/software/homo_sapiens/ --FASTAURL /g/data/xx92/vdp3.0/software/homo_sapiens/

Plugins:
- installing "CADD"
- This plugin requires data
- See /g/data/xx92/vdp3.0/GRCh38/vep_index//Plugins/CADD.pm for details
- OK

- installing "LoF"
- This plugin requires installation
- This plugin requires data
- See /g/data/xx92/vdp3.0/GRCh38/vep_index//Plugins/LoF.pm for details
- OK

- installing "SpliceRegion"
- add "--plugin SpliceRegion" to your VEP command to use this plugin
- OK

- installing "ExAC"
- This plugin requires data
- See /g/data/xx92/vdp3.0/GRCh38/vep_index//Plugins/ExAC.pm for details
- OK

- installing "gnomADc"
- add "--plugin gnomADc" to your VEP command to use this plugin
- OK

- installing "Phenotypes"
- This plugin requires data
- See /g/data/xx92/vdp3.0/GRCh38/vep_index//Plugins/Phenotypes.pm for details
- OK

- installing "GO"
curl failed (000), trying to fetch using LWP::Simple
- add "--plugin GO" to your VEP command to use this plugin
- OK

- installing "CSN"
- add "--plugin CSN" to your VEP command to use this plugin
- OK

- installing "miRNA"
- add "--plugin miRNA" to your VEP command to use this plugin
- OK

Plugins data:
mkdir /g/data/xx92/vdp3.0/GRCh38/vep_db
cd /g/data/xx92/vdp3.0/GRCh38/vep_db

CADD: 
wget https://krishna.gs.washington.edu/download/CADD/v1.5/GRCh38/whole_genome_SNVs.tsv.gz
wget https://krishna.gs.washington.edu/download/CADD/v1.5/GRCh38/whole_genome_SNVs.tsv.gz.tbi

ClinVar:
wget ftp://ftp.ncbi.nlm.nih.gov/pub/clinvar/vcf_GRCh38/clinvar_20200310.vcf.gz
wget ftp://ftp.ncbi.nlm.nih.gov/pub/clinvar/vcf_GRCh38/clinvar_20200310.vcf.gz.tbi

gnomAD:

hash=$(echo "marcin.adamski@anu.edu.au:Marcin00#" | base64); curl -H "Authorization: Basic $hash" https://cancer.sanger.ac.uk/cosmic/file_download/GRCh38/cosmic/v90/VCF/CosmicCodingMuts.vcf.gz | awk -F ":" '{printf("%s:%s",$2,substr($3, 1, length($3)-1))}'
hash=$(echo "marcin.adamski@anu.edu.au:Marcin00#" | base64); curl -H "Authorization: Basic $hash" https://cancer.sanger.ac.uk/cosmic/file_download/GRCh38/cosmic/v90/VCF/CosmicNonCodingVariants.vcf.gz | awk -F ":" '{printf("%s:%s",$2,substr($3, 1, length($3)-1))}'

#PEDDY
module load python3/3.7.4
cd <software>
mkdir pythonlib
export PYTHONPATH=<software>/pythonlib/lib/python3.7/site-packages:<software>/peddy"
export PATH="<software>/pythonlib/bin:$PATH"
pip3.7 install --prefix=/g/data/xx92/vdp3.0/software/pythonlib cyvcf2 pytz networkx pandas scikit-learn toolshed click coloredlogs seaborn
git clone https://github.com/brentp/peddy
cd peddy
pip3.7 install --prefix=/g/data/xx92/vdp3.0/software/pythonlib --editable .
#to check:
python3.7 -m peddy -p 4 --plot --prefix ceph-1463 data/ceph1463.peddy.vcf.gz data/ceph1463.ped
#there is an issue in curent peddy:
File "peddy/peddy/cli.py", line 105, in correct_sex_errors
  osc[sel] = ito
IndexError: arrays used as indices must be of integer (or boolean) type
To fix:
cli.py line 104 from sel = (gt & sf & (sc == ifrom)) to: sel = (gt & sf & (sc == ifrom)) != 0

#target bed's for targeted sequencing - all sequencing is targeted, only for WGS chromosomes are the targets
#Agilen WES target (padded) bed file
https://earray.chem.agilent.com/suredesign/search.htm
#must register first
#select 'SureSelect Clinical Research Exome V2' from 'Agilent Catalog'
#choose hg38, click 'download'
#choose S30409818_Padded.bed
#make exon regions for calculating exon coverage:
bedtools intersect -a S30409818_Regions.bed -b S30409818_Padded.bed -wa -wb | cut -f1-3,7 | bedtools merge -i - -c 4 -o distinct  | sed "s/-,//" | sed "s/,-//" | awk '{if($3 - $2 > 3) print}' >S30409818_Regions_named.bed
java -jar ../../software/picard.jar BedToIntervalList I=S30409818_Regions_named.bed O=S30409818_Regions_named.interval SD=../GATK_bundle_v0/Homo_sapiens_assembly38.dict

#'fake' wgs.bed for WGS sequencing:
chr1	0	999999999
chr2	0	999999999
chr3	0	999999999
chr4	0	999999999
chr5	0	999999999
chr6	0	999999999
chr7	0	999999999
chr8	0	999999999
chr9	0	999999999
chr10	0	999999999
chr11	0	999999999
chr12	0	999999999
chr13	0	999999999
chr14	0	999999999
chr15	0	999999999
chr16	0	999999999
chr17	0	999999999
chr18	0	999999999
chr19	0	999999999
chr20	0	999999999
chr21	0	999999999
chr22	0	999999999
chrX	0	999999999
chrY	0	999999999
chrM	0	999999999

#GATK bundle from Google Cloud bucket
# use https://cloud.google.com/storage/docs/gsutil/commands/cp for reference on gsutil
# actual bucked link may change in the future (e.g. 'v0' may become obsolete and 'v1' current)
# always check current version on GATK web site
# the assembly in there is the 'hs38DH' - reference contains the primary assembly of GRCh38 plus the ALT contigs and additionally decoy contigs and HLA genes. This assembly is strongly recommended for GRCh38 mapping by the BWA-kit pipeline. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5155401/
mkdir -p gatk_bundle
cd gatk_bundle
gcloud auth login #and follow instructions to login
gsutil -m cp -r gs://genomics-public-data/resources/broad/hg38/v0/* ./

# https://github.com/gatk-workflows/gatk4-exome-analysis-pipeline/blob/master/tasks/Alignment.wdl
#GetBwaVersion
/usr/gitc/bwa 2>&1 | grep -e '^Version' | sed 's/Version: //'

Use of references for recalibration:
https://gatkforums.broadinstitute.org/gatk/discussion/comment/56727
#BaseRecalibrator:
	Homo_sapiens_assembly38.dbsnp138.vcf
	Mills_and_1000G_gold_standard.indels.hg38.vcf.gz
	Homo_sapiens_assembly38.known_indels.vcf.gz

#VariantRecalibrator
	indels:
	Homo_sapiens_assembly38.dbsnp138.vcf
	Mills_and_1000G_gold_standard.indels.hg38.vcf.gz
	Axiom_Exome_Plus.genotypes.all_populations.poly.hg38.vcf.gz	

	SNPs:
	Homo_sapiens_assembly38.dbsnp138.vcf
	hapmap_3.3.hg38.vcf.gz
	1000G_omni2.5.hg38.vcf.gz
	1000G_phase1.snps.high_confidence.hg38.vcf.gz





https://github.com/gatk-workflows/gatk4-exome-analysis-pipeline/blob/master/tasks/Qc.wdl
java -Xms2000m -jar /usr/gitc/picard.jar \
      CollectQualityYieldMetrics \
      INPUT=~{input_bam} \
      OQ=true \
      OUTPUT=~{metrics_filename}

java -Xms5000m -jar /usr/gitc/picard.jar \
      CollectMultipleMetrics \
      INPUT=~{input_bam} \
      OUTPUT=~{output_bam_prefix} \
      ASSUME_SORTED=true \
      PROGRAM=null \
      PROGRAM=CollectBaseDistributionByCycle \
      PROGRAM=CollectInsertSizeMetrics \
      PROGRAM=MeanQualityByCycle \
      PROGRAM=QualityScoreDistribution \
      METRIC_ACCUMULATION_LEVEL=null \
      METRIC_ACCUMULATION_LEVEL=ALL_READS

java -Dsamjdk.buffer_size=131072 \
      -XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Xms2000m \
      -jar /usr/gitc/picard.jar \
      CrosscheckFingerprints \
      OUTPUT=~{metrics_filename} \
      HAPLOTYPE_MAP=~{haplotype_database_file} \
      EXPECT_ALL_GROUPS_TO_MATCH=true \
      INPUT=~{sep=' INPUT=' input_bams} \
      LOD_THRESHOLD=~{lod_threshold} \
      CROSSCHECK_BY=~{cross_check_by}

java -Dsamjdk.buffer_size=131072 \
      -XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Xms2g  \
      -jar /usr/gitc/picard.jar \
      CheckFingerprint \
      INPUT=~{input_bam} \
      SUMMARY_OUTPUT=~{summary_metrics_location} \
      DETAIL_OUTPUT=~{detail_metrics_location} \
      GENOTYPES=~{genotypes} \
      HAPLOTYPE_MAP=~{haplotype_database_file} \
      SAMPLE_ALIAS="~{sample}" \
      IGNORE_READ_GROUPS=true

java -Xms~{java_memory_size}m -jar /usr/gitc/picard.jar \
      ValidateSamFile \
      INPUT=~{input_bam} \
      OUTPUT=~{report_filename} \
      REFERENCE_SEQUENCE=~{ref_fasta} \
      ~{"MAX_OUTPUT=" + max_output} \
      IGNORE=~{default="null" sep=" IGNORE=" ignore} \
      MODE=VERBOSE \
      ~{default='SKIP_MATE_VALIDATION=false' true='SKIP_MATE_VALIDATION=true' false='SKIP_MATE_VALIDATION=false' is_outlier_data} \
      IS_BISULFITE_SEQUENCED=false

java -Xms2000m -jar /usr/gitc/picard.jar \
      CollectWgsMetrics \
      INPUT=~{input_bam} \
      VALIDATION_STRINGENCY=SILENT \
      REFERENCE_SEQUENCE=~{ref_fasta} \
      INCLUDE_BQ_HISTOGRAM=true \
      INTERVALS=~{wgs_coverage_interval_list} \
      OUTPUT=~{metrics_filename} \
      USE_FAST_ALGORITHM=true \
      READ_LENGTH=~{read_length}

java -Xms~{java_memory_size}m -jar /usr/gitc/picard.jar \
      CollectRawWgsMetrics \
      INPUT=~{input_bam} \
      VALIDATION_STRINGENCY=SILENT \
      REFERENCE_SEQUENCE=~{ref_fasta} \
      INCLUDE_BQ_HISTOGRAM=true \
      INTERVALS=~{wgs_coverage_interval_list} \
      OUTPUT=~{metrics_filename} \
      USE_FAST_ALGORITHM=true \
      READ_LENGTH=~{read_length}

java -Xms~{java_memory_size}m -jar /usr/gitc/picard.jar \
      CollectHsMetrics \
      INPUT=~{input_bam} \
      REFERENCE_SEQUENCE=~{ref_fasta} \
      VALIDATION_STRINGENCY=SILENT \
      TARGET_INTERVALS=~{target_interval_list} \
      BAIT_INTERVALS=~{bait_interval_list} \
      METRIC_ACCUMULATION_LEVEL=null \
      METRIC_ACCUMULATION_LEVEL=SAMPLE \
      METRIC_ACCUMULATION_LEVEL=LIBRARY \
      OUTPUT=~{metrics_filename}
  
java -Xms1000m -jar /usr/gitc/picard.jar \
      CalculateReadGroupChecksum \
      INPUT=~{input_bam} \
      OUTPUT=~{read_group_md5_filename}

gatk --java-options -Xms6000m \
      ValidateVariants \
      -V ~{input_vcf} \
      -R ~{ref_fasta} \
      -L ~{calling_interval_list} \
      ~{true="-gvcf" false="" is_gvcf} \
      --validation-type-to-exclude ALLELES \
      --dbsnp ~{dbsnp_vcf}

java -Xms2000m -jar /usr/gitc/picard.jar \
      CollectVariantCallingMetrics \
      INPUT=~{input_vcf} \
      OUTPUT=~{metrics_basename} \
      DBSNP=~{dbsnp_vcf} \
      SEQUENCE_DICTIONARY=~{ref_dict} \
      TARGET_INTERVALS=~{evaluation_interval_list} \
      ~{true="GVCF_INPUT=true" false="" is_gvcf}

# https://github.com/gatk-workflows/gatk4-exome-analysis-pipeline/blob/master/tasks/BamProcessing.wdl

java -Dsamjdk.compression_level=~{compression_level} -Xms4000m -jar /usr/gitc/picard.jar SortSam 
      INPUT=~{input_bam} \
      OUTPUT=~{output_bam_basename}.bam \
      SORT_ORDER="coordinate" \
      CREATE_INDEX=true \
      CREATE_MD5_FILE=true \
      MAX_RECORDS_IN_RAM=300000

java -Dsamjdk.compression_level=~{compression_level} -Xms~{java_memory_size}g -jar /usr/gitc/picard.jar \
      MarkDuplicates \
      INPUT=~{sep=' INPUT=' input_bams} \
      OUTPUT=~{output_bam_basename}.bam \
      METRICS_FILE=~{metrics_filename} \
      VALIDATION_STRINGENCY=SILENT \
      ~{"READ_NAME_REGEX=" + read_name_regex} \
      OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500 \
      ASSUME_SORT_ORDER="queryname" \
      CLEAR_DT="false" \
      ADD_PG_TAG_TO_READS=false

gatk --java-options "-XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -XX:+PrintFlagsFinal \
      -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps -XX:+PrintGCDetails \
      -Xloggc:gc_log.log -Xms5g" \
      BaseRecalibrator \
      -R ~{ref_fasta} \
      -I ~{input_bam} \
      --use-original-qualities \
      -O ~{recalibration_report_filename} \
      --known-sites ~{dbsnp_vcf} \
      --known-sites ~{sep=" -known-sites " known_indels_sites_vcfs} \
      -L ~{sep=" -L " sequence_group_interval}

  gatk --java-options "-XX:+PrintFlagsFinal -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps \
      -XX:+PrintGCDetails -Xloggc:gc_log.log \
      -XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Dsamjdk.compression_level=~{compression_level} -Xms3000m" \
      ApplyBQSR \
      --create-output-bam-md5 \
      --add-output-sam-program-record \
      -R ~{ref_fasta} \
      -I ~{input_bam} \
      --use-original-qualities \
      -O ~{output_bam_basename}.bam \
      -bqsr ~{recalibration_report} \
      --static-quantized-quals 10 \
      --static-quantized-quals 20 \
      --static-quantized-quals 30 \
      -L ~{sep=" -L " sequence_group_interval}

   java -Dsamjdk.compression_level=~{compression_level} -Xms2000m -jar /usr/gitc/picard.jar \
      GatherBamFiles \
      INPUT=~{sep=' INPUT=' input_bams} \
      OUTPUT=~{output_bam_basename}.bam \
      CREATE_INDEX=true \
      CREATE_MD5_FILE=true


????? GenerateSubsettedContaminationResources 
   grep -vE "^@" ~{target_interval_list} |
       awk -v OFS='\t' '$2=$2-1' |
       /app/bedtools intersect -c -a ~{contamination_sites_bed} -b - |
       cut -f6 > ~{target_overlap_counts}
????? CheckContamination 





https://github.com/gatk-workflows/gatk4-exome-analysis-pipeline/blob/master/tasks/GermlineVariantDiscovery.wdl
gatk --java-options "-Xms6000m -XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10" \
      HaplotypeCaller \
      -R ~{ref_fasta} \
      -I ~{input_bam} \
      -L ~{interval_list} \
      -O ~{output_file_name} \
      -contamination ~{default=0 contamination} \
      -G StandardAnnotation -G StandardHCAnnotation ~{true="-G AS_StandardAnnotation" false="" make_gvcf} \
      -new-qual \
      -GQB 10 -GQB 20 -GQB 30 -GQB 40 -GQB 50 -GQB 60 -GQB 70 -GQB 80 -GQB 90 \
      ~{true="-ERC GVCF" false="" make_gvcf} \
      ~{bamout_arg}

java -Xms2000m -jar /usr/gitc/picard.jar \
      MergeVcfs \
      INPUT=~{sep=' INPUT=' input_vcfs} \
      OUTPUT=~{output_vcf_name}

gatk --java-options "-Xms3000m" \
      VariantFiltration \
      -V ~{input_vcf} \
      -L ~{interval_list} \
      --filter-expression "QD < 2.0 || FS > 30.0 || SOR > 3.0 || MQ < 40.0 || MQRankSum < -3.0 || ReadPosRankSum < -3.0" \
      --filter-name "HardFiltered" \
      -O ~{output_vcf_name}

gatk --java-options -Xmx10g CNNScoreVariants \
       -V ~{input_vcf} \
       -R ~{ref_fasta} \
       -O ~{output_vcf} \
       ~{bamout_param} \
       -tensor-type ~{tensor_type}

gatk --java-options -Xmx6g FilterVariantTranches \
      -V ~{input_vcf} \
      -O ~{vcf_basename}.filtered.vcf.gz \
      ~{sep=" " prefix("--snp-tranche ", snp_tranches)} \
      ~{sep=" " prefix("--indel-tranche ", indel_tranches)} \
      --resource ~{hapmap_resource_vcf} \
      --resource ~{omni_resource_vcf} \
      --resource ~{one_thousand_genomes_resource_vcf} \
      --resource ~{dbsnp_resource_vcf} \
      --info-key ~{info_key} \
      --create-output-variant-index true

