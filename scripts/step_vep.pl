#! /usr/bin/perl -w 
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Path qw(make_path remove_tree);
use File::Basename;
use Pod::Usage;
use Cwd;
use modules::Definitions;
use modules::SystemCall;
use modules::Exception;
use modules::Config;
use modules::PED;
use modules::Pipeline;
use modules::Cohort;
use modules::Utils;
use modules::Semaphore;

use vars qw(%OPT);


GetOptions(\%OPT, 
	   		"help|h",
	   		"man|m",
	   		"config=s",
	   		"step=s",
	   		"cohort=s",
	   		"individual=s",
	   		"readfile=s",
	   		"split=s",
	   		"exit=s"
	   		);
	   		
pod2usage(-verbose => 2) if $OPT{man};
pod2usage(1) if ($OPT{help});

	   
=pod

=head1 SYNOPSIS

step_<name>.pl

Required flags: NONE

=head1 OPTIONS

    -config  path to cohort configuration file
    -cohort  cohort name
    -help    brief help message
    -man     full documentation

=head1 NAME

step_<name>.pl -> Does something useful

=head1 DESCRIPTION

Fab 2020

a script that ...

=head1 AUTHOR

Marcin Adamski

=head1 EXAMPLE

./step_<name>.pl

=cut


my $step       = $OPT{step};
my $split      = $OPT{'split'};
my $cohort     = $OPT{cohort};
my $individual = $OPT{individual};

die("this script requires at least arguments --cohort <cohort> and --step <step>\nrun: $0 --help to hopefully get some brief help\n") if(!defined $cohort | !defined $step);

warn "running pipeline step '$step".(defined $split? $split: '')."' on cohort '$cohort'\n";

my $Config   = modules::Config->new($OPT{config});
my $Syscall  = modules::SystemCall->new();

my $pversion = $Config->read("global", "version");
my $codebase = $Config->read("directories", "pipeline");
warn "pipeline version: '$pversion', codebase: '$codebase'\n";

my $dir_cohort  = $Config->read("cohort", "dir");
modules::Exception->throw("Can't access cohort directory $dir_cohort") if(!-d $dir_cohort);
my $dir_run = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:$step", "dir");
modules::Exception->throw("Can't access cohort run directory $dir_run") if(!-d $dir_run);
my $dir_tmp = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("directories", "tmp");
modules::Exception->throw("Can't access cohort run TEMP directory $dir_tmp") if(!-d $dir_tmp);

my $PED = modules::PED->new("$dir_cohort/$cohort.pedx");
modules::Exception->throw("cohort PED file must contain exactly one family") if(scalar keys %{$PED->ped} != 1);
modules::Exception->throw("cohort id submited as argument is not the same as cohort id in PED: '$cohort' ne '".(keys %{$PED->ped})[0]."'") if((keys %{$PED->ped})[0] ne $cohort);
#my $Cohort = modules::Cohort->new("$cohort", $Config, $PED);
#$Cohort->add_individuals_ped();
#my $Pipeline = modules::Pipeline->new(cohort => $Cohort);
#$Pipeline->get_pipesteps;
#$Pipeline->get_qjobs;

my $vep_bin = $Config->read("step:$step", "vep_bin");
my $bgzip_bin = $Config->read("step:$step", "bgzip_bin");
my $bcftools_bin = $Config->read("step:$step", "bcftools_bin");
my $tabix_bin = $Config->read("step:$step", "tabix_bin");
my $cmdx;

#warn " *************** UNCOMMENT BCFTOOLS, VEP and TABIX *********************\n";

my $r;
#we need to split multi allelic loci loci and remove possibly duplicates
#command below will work only if vcf header is 4.2 - AD field must be defined as Number=R, not Number=. or Number=1
#GATK generates it OK, Strelka and Varscan not. But if the vcf merge between callers in the previous step was done with GATK being the first, the Number=R
#otherwise it would be necessary to manualy fix the AD field def. in the VCF header 
my $cmd = "$bcftools_bin norm -m -both $dir_run/$cohort.$split.vcf.gz | $bcftools_bin norm -d none -O v -o $dir_run/$cohort.$split.vep_in.vcf";
#warn "$cmd\n"; exit(PIPE_NO_PROGRESS);
$r = $Syscall->run($cmd);
exit(1) if($r);

my $index_dir    = $Config->read("directories", "vep_index");
my $gnomad_vcf   = $Config->read("step:$step", "gnomad_vcf");
my $clinvar_vcf  = $Config->read("step:$step", "clinvar_vcf");
my $cad          = $Config->read("step:$step", "cad");
my $fasta        = $Config->read("step:$step", "fasta");
my $ncpu         = $Config->read("step:$step", "pbs_ncpus");

#my $cosmic_coding_vcf    = $Config->read("step:$step", "cosmic_coding_vcf");
#my $cosmic_noncoding_vcf = $Config->read("step:$step", "cosmic_noncoding_vcf");
#--custom $cosmic_coding_vcf,COSMIC_CODING,vcf,exact,0,LEGACY_ID --custom $cosmic_noncoding_vcf,COSMIC_NONCODING,vcf,exact,0,LEGACY_ID 

$cmd = "--force_overwrite --cache --offline --species homo_sapiens --merged --fork $ncpu --domains --af --pubmed --check_existing --biotype --regulatory --hgvs --numbers --symbol --canonical --sift b --polyphen b --flag_pick --vcf --use_transcript_ref --plugin SpliceRegion --plugin CADD,$cad --custom $clinvar_vcf,ClinVar,vcf,exact,0,CLNSIG,CLNREVSTAT,CLNDN --custom $gnomad_vcf,gnomAD,vcf,exact,0,AF,AF_female,AF_male,AF_afr,AF_afr_female,AF_afr_male,AF_ami,AF_ami_female,AF_ami_male,AF_amr,AF_amr_female,AF_amr_male,AF_asj,AF_asj_female,AF_asj_male,AF_eas,AF_eas_female,AF_eas_male,AF_fin,AF_fin_female,AF_fin_male,AF_nfe,AF_nfe_female,AF_nfe_male,AF_sas,AF_sas_female,AF_sas_male,AF_oth,AF_oth_female,AF_oth_male --dir $index_dir --fasta $fasta --I $dir_run/$cohort.$split.vep_in.vcf --stats_text --stats_file $dir_run/$cohort.$split.vep_stats.txt -o stdout | $bgzip_bin -c >$dir_run/$cohort.$split.vep.vcf.gz";
$cmd =~ s/\s+-/ \\\n  -/g;
$cmd = "$vep_bin $cmd";
#warn "$cmd\n"; exit(PIPE_NO_PROGRESS);
warn "running Ensembl VEP...\n";
$r = $Syscall->run($cmd);
warn "finished Ensembl VEP\n";
exit(1) if($r);

$cmd = "$tabix_bin -f $dir_run/$cohort.$split.vep.vcf.gz";
$r = $Syscall->run($cmd);
exit(1) if($r);

open I, "$bgzip_bin -dc $dir_run/$cohort.$split.vep.vcf.gz|" or modules::Exception->throw("Can't do: '$bgzip_bin -dc $dir_run/$cohort.$split.vep.vcf.gz|'");
open O, ">$dir_run/$cohort.$split.vep.tsv" or modules::Exception->throw("Can't open '$dir_run/$cohort.$split.vep.tsv' for writing");
my %vepfld;
my %sampcln;
my $header_vep;

while(<I>){
	chomp;
	if(/^##INFO=<ID=CSQ,/){ ##INFO=<ID=CSQ,Number=.,Type=String,Description="Consequence annotations from Ensembl VEP. Format: Allele|Consequence|IMPACT|SYMBOL|Gene|Feature_type|Feature|BIOTYPE|EXON|INTRON|HGVSc|HGVSp|cDNA_position|CDS_position|Protein_position|Amino_acids|Codons|Existing_variation|DISTANCE|STRAND|FLAGS|SYMBOL_SOURCE|HGNC_ID|CANONICAL|REFSEQ_MATCH|SOURCE|GIVEN_REF|USED_REF|BAM_EDIT|SIFT|PolyPhen|DOMAINS|HGVS_OFFSET|AF|CLIN_SIG|SOMATIC|PHENO|PUBMED|MOTIF_NAME|MOTIF_POS|HIGH_INF_POS|MOTIF_SCORE_CHANGE|SpliceRegion|CADD_PHRED|CADD_RAW|ClinVar|ClinVar_CLNSIG|ClinVar_CLNREVSTAT|ClinVar_CLNDN|gnomAD|gnomAD_AF|gnomAD_AF_female|gnomAD_AF_male|gnomAD_AF_afr|gnomAD_AF_afr_female|gnomAD_AF_afr_male|gnomAD_AF_ami|gnomAD_AF_ami_female|gnomAD_AF_ami_male|gnomAD_AF_amr|gnomAD_AF_amr_female|gnomAD_AF_amr_male|gnomAD_AF_asj|gnomAD_AF_asj_female|gnomAD_AF_asj_male|gnomAD_AF_eas|gnomAD_AF_eas_female|gnomAD_AF_eas_male|gnomAD_AF_fin|gnomAD_AF_fin_female|gnomAD_AF_fin_male|gnomAD_AF_nfe|gnomAD_AF_nfe_female|gnomAD_AF_nfe_male|gnomAD_AF_sas|gnomAD_AF_sas_female|gnomAD_AF_sas_male|gnomAD_AF_oth|gnomAD_AF_oth_female|gnomAD_AF_oth_male">
		s/^.+Ensembl VEP. Format: //;
		s/\">\s*$//;
		#Allele|Consequence|IMPACT|SYMBOL|Gene|Feature_type|Feature|BIOTYPE|EXON|INTRON|HGVSc|HGVSp|cDNA_position|CDS_position|Protein_position|Amino_acids|Codons|Existing_variation|DISTANCE|STRAND|FLAGS|SYMBOL_SOURCE|HGNC_ID|CANONICAL|REFSEQ_MATCH|SOURCE|GIVEN_REF|USED_REF|BAM_EDIT|SIFT|PolyPhen|DOMAINS|HGVS_OFFSET|AF|CLIN_SIG|SOMATIC|PHENO|PUBMED|MOTIF_NAME|MOTIF_POS|HIGH_INF_POS|MOTIF_SCORE_CHANGE|SpliceRegion|CADD_PHRED|CADD_RAW|ClinVar|ClinVar_CLNSIG|ClinVar_CLNREVSTAT|ClinVar_CLNDN|gnomAD|gnomAD_AF|gnomAD_AF_female|gnomAD_AF_male|gnomAD_AF_afr|gnomAD_AF_afr_female|gnomAD_AF_afr_male|gnomAD_AF_ami|gnomAD_AF_ami_female|gnomAD_AF_ami_male|gnomAD_AF_amr|gnomAD_AF_amr_female|gnomAD_AF_amr_male|gnomAD_AF_asj|gnomAD_AF_asj_female|gnomAD_AF_asj_male|gnomAD_AF_eas|gnomAD_AF_eas_female|gnomAD_AF_eas_male|gnomAD_AF_fin|gnomAD_AF_fin_female|gnomAD_AF_fin_male|gnomAD_AF_nfe|gnomAD_AF_nfe_female|gnomAD_AF_nfe_male|gnomAD_AF_sas|gnomAD_AF_sas_female|gnomAD_AF_sas_male|gnomAD_AF_oth|gnomAD_AF_oth_female|gnomAD_AF_oth_male
		s/\|/\t/g;
		my @a = split "\t";
		for(my $i = 0; $i < scalar @a; $i++){
			$vepfld{$a[$i]} = $i;
		}
		#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	CCG0467	CCG0468	CCG0469
		#$header_vep = "chr\tpos\tref\talt";
		$header_vep ="\t$_\n";
	}
	if(/^#CHROM/){
		my @a = split "\t";
		#warn "samples:\n";
		for(my $i = 9; $i < scalar @a; $i++){
			$sampcln{$a[$i]} = $i;
			#warn "  $a[$i] = $i\n";
		}
		print O "chr\tpos\tref\talt\tRD\tAD0\tAD1";
		foreach(sort{$sampcln{$a} <=> $sampcln{$b}} keys %sampcln){
			print O "\t$_-GT";
		}
		foreach(sort{$sampcln{$a} <=> $sampcln{$b}} keys %sampcln){
			print O "\t$_-GQ";
		}
		foreach(sort{$sampcln{$a} <=> $sampcln{$b}} keys %sampcln){
			print O "\t$_-RD";
		}
		foreach(sort{$sampcln{$a} <=> $sampcln{$b}} keys %sampcln){
			print O "\t$_-AD0";
		}
		foreach(sort{$sampcln{$a} <=> $sampcln{$b}} keys %sampcln){
			print O "\t$_-AD1";
		}
		print O "\tcaller\tVQSLOD\tMQ";
		print O $header_vep;
	}
	next if(/^#/);

	#here we get the real records:
	my @fld = split "\t";
	my @frmtags = split(':', $fld[8]);
	my %frmtag;
	for(my $i = 0; $i < scalar @frmtags; $i++){
		$frmtag{$frmtags[$i]} = $i;
	}
	my @gt;
	my @ad0;
	my @ad1;
	my @gq;
	foreach(sort{$sampcln{$a} <=> $sampcln{$b}} keys %sampcln){
		my @a = split(':', $fld[$sampcln{$_}]);
		#warn join("\t", @fld)."\n" if(!defined $frmtag{DP});
		push @gt, $a[$frmtag{GT}];
		my @adp;
		if($a[$frmtag{AD}] =~ /,/){ #GATK HC and strelka reports AD per allele separated with ','
			@adp = split ',', $a[$frmtag{AD}];
		}
		else{ #varscan reports AD as a single value for variant and RD with value for reference
			modules::Exception->throw("tag AD has only a single value (for the variant) and tag RD (for the ref.) is missing in VCF file line $.") if(!defined $frmtag{RD});
			@adp = ($a[$frmtag{RD}], $a[$frmtag{AD}]);
		}
		push @ad0, $adp[0];
		push @ad1, $adp[1];
		push @gq, $a[$frmtag{GQ}];
	}

	my $csq    = '';
	my $vqslod = '';
	my $mq     = '';
	my $caller = '';
	$vqslod = $1 if($fld[7] =~ /VQSLOD=([^\;]+)/);
	$mq     = $1 if($fld[7] =~ /MQ=([^\;]+)/);
	$caller = $1 if($fld[7] =~ /caller=([^\;]+)/);
	$csq    = $1 if($fld[7] =~ /CSQ=([^\;]+)/);
	$csq =~ s/\|/\t/g;
	my @csqs = split ",", $csq;
	for(my $i = 0; $i < scalar @csqs; $i++){
		$csqs[$i] =~ s/\&/,/g;
		my @a = split "\t", $csqs[$i];
		if(defined $a[$vepfld{PICK}] && $a[$vepfld{PICK}] ne '' && $a[$vepfld{PICK}] == 1){
			my(@rds, $rd, $ad0, $ad1); #global stats for the variant accross all samples
			for(my $i = 0; $i < scalar @ad0; $i++){
				my $a0 = $ad0[$i] eq '.'? 0: $ad0[$i];
				my $a1 = $ad1[$i] eq '.'? 0: $ad1[$i];
				$rds[$i] = $a0 + $a1;
				$ad0 += $a0;
				$ad1 += $a1;
				$rd  += $a0 + $a1;
			}
			if($rd > 0){ #in some multiallelic cases strelka reports variants with 0 read support for the allele (facepalm)
				print O join("\t", $fld[0], $fld[1], $fld[3], $fld[4])."\t$rd\t$ad0\t$ad1\t".join("\t", @gt)."\t".join("\t", @gq)."\t".join("\t", @rds)."\t".join("\t", @ad0)."\t".join("\t", @ad1)."\t$caller\t$vqslod\t$mq";
				print O "\t$csqs[$i]\n";
			}
			else{
				warn "WARN: read depth filter dropped variant $fld[0]:$fld[1] $fld[3]/$fld[4] with RD = $rd caller = $caller\n";
			}
		}
	}
}
close O;
close I;

unlink("$dir_run/$cohort.$split.vep_in.vcf"); #lets skip any error control on this one ;)

exit(0);

END{
	warn "done script ".basename(__FILE__)."\n"
}
