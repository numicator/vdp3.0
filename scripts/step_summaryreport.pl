#! /usr/bin/perl -w 
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Path qw(make_path remove_tree);
use File::Basename;
use Pod::Usage;
use Cwd;
use PDF::API2::Simple; 
use PDF::Table; 
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
my $dir_result = $dir_cohort.'/'.$Config->read("directories", "result");
modules::Exception->throw("Can't access cohort run directory $dir_result") if(!-d $dir_result);
my $dir_tmp = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("directories", "tmp");
modules::Exception->throw("Can't access cohort run TEMP directory $dir_tmp") if(!-d $dir_tmp);
my $dir_fastqc = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:fastqc", "dir");
modules::Exception->throw("Can't access cohort run TEMP directory $dir_fastqc") if(!-d $dir_fastqc);
my $dir_peddy = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:report_snv", "peddy_dir");
modules::Exception->throw("Can't access cohort run TEMP directory $dir_peddy") if(!-d $dir_peddy);
my $dir_vqsr = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:gatk_vqsr_recal_snp", "dir");
modules::Exception->throw("Can't access cohort run TEMP directory $dir_vqsr") if(!-d $dir_vqsr);
my $dir_bam = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:bqsr_gather_bam", "dir");
modules::Exception->throw("Can't access cohort run TEMP directory $dir_bam") if(!-d $dir_bam);
my $dir_vcf = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:report_snv", "dir");
modules::Exception->throw("Can't access cohort run TEMP directory $dir_vcf") if(!-d $dir_vcf);

my $dir_ploidy = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:gatk_cnv_ploidy", "dir");
modules::Exception->throw("Can't access cohort run directory $dir_ploidy") if(!-d $dir_ploidy);

my $dir_cnv = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:report_cnv", "dir");
modules::Exception->throw("Can't access cohort run directory $dir_cnv") if(!-d $dir_cnv);


my $PED = modules::PED->new("$dir_cohort/$cohort.pedx");
modules::Exception->throw("cohort PED file must contain exactly one family") if(scalar keys %{$PED->ped} != 1);
modules::Exception->throw("cohort id submited as argument is not the same as cohort id in PED: '$cohort' ne '".(keys %{$PED->ped})[0]."'") if((keys %{$PED->ped})[0] ne $cohort);
my $Cohort = modules::Cohort->new("$cohort", $Config, $PED);
$Cohort->add_individuals_ped();
my $Pipeline = modules::Pipeline->new(cohort => $Cohort);
$Pipeline->get_pipesteps;
#$Pipeline->get_qjobs;

my $timestamp = modules::Utils::get_time_stamp;
my $reference   = $Config->read("references", "genome_fasta");
my $username    = $Config->read("cohort", "username");
my $time_start  = $Config->read("cohort", "time_start");

my $filter_rd_cvr = $Config->read("step:report_snv", "filter_rd_cvr");
my $cnv_model_calls = $Config->read("step:gatk_cnv_ploidy", "contig_ploidy_calls"); 

$username =~ s/^([^:]+):(.+)/$2 \($1\)/;

my $page_num  = 1; 

my %indv_data;

my @indv_id;
my @ln;
foreach my $indv(@{$Cohort->individual}){
	push @indv_id, $indv->id;
}
@indv_id = sort @indv_id;

foreach my $indv(@indv_id){
	my $fid = $PED->{ped}{$Cohort->id}{$indv}{father};
	my $mid = $PED->{ped}{$Cohort->id}{$indv}{mother};
	my $aff = $PED->{ped}{$Cohort->id}{$indv}{phenotype};
	my $sex = $PED->{ped}{$Cohort->id}{$indv}{sex};
	my $seq = $PED->{ped}{$Cohort->id}{$indv}{capturekit};
	
	$fid = '-' if(!defined $fid || $fid eq '0' || $fid eq '-9' || $fid eq '');
	$mid = '-' if(!defined $mid || $mid eq '0' || $mid eq '-9' || $mid eq '');
	$aff = $aff eq '2'? 'Y': 'N';
	$sex = $sex eq '2'? 'F': 'M';
	$seq = 'UNKNOWN' if(!defined $seq);
	
	$indv_data{$indv}{sex_ped} = $sex;
	$indv_data{$indv}{affected} = $aff;
	$indv_data{$indv}{mother} = $mid;
	$indv_data{$indv}{father} = $fid;
	#push @ln, [$indv, "sex: $sex   affected: $aff   father: $fid   mother: $mid"]
	push @ln, [$indv, "sex: $sex", "affected: $aff", "father: $fid", "mother: $mid"]
}

my %head;
#Check sex of the individuals
open F, "$dir_peddy/$cohort.sex_check.csv" or modules::Exception->throw("Can't open '$dir_peddy/$cohort.sex_check.csv'");
undef %head;
while(<F>){
	chomp;
	my @a = split ",";
	if(!%head){
		for(my $i = 0; $i < scalar @a; $i++){
			#sample_id,ped_sex,hom_ref_count,het_count,hom_alt_count,het_ratio,predicted_sex,error
			$head{$a[$i]} = $i;
		}
		next;
	}
	$indv_data{$a[$head{sample_id}]}{sex_ok} = $a[$head{error}] eq 'False'? 'Y': 'N';
	$indv_data{$a[$head{sample_id}]}{x_het_ratio} = $a[$head{het_ratio}];
}
close F;

#Check ancestry and heterozygosity of the individuals
open F, "$dir_peddy/$cohort.het_check.csv" or modules::Exception->throw("Can't open '$dir_peddy/$cohort.het_check.csv'");
undef %head;
while(<F>){
	chomp;
	my @a = split ",";
	if(!%head){
		for(my $i = 0; $i < scalar @a; $i++){
			#sample_id,depth_outlier,het_count,het_ratio,idr_baf,mean_depth,median_depth,p10,p90,sampled_sites,call_rate,ancestry-prediction,ancestry-prob,PC1,PC2,PC3,PC4
			$head{$a[$i]} = $i;
		}
		next;
	}
	$indv_data{$a[$head{sample_id}]}{ancestry} = $a[$head{'ancestry-prediction'}];
	$indv_data{$a[$head{sample_id}]}{ancestry_prob} = $a[$head{'ancestry-prob'}];
	$indv_data{$a[$head{sample_id}]}{het_ratio} = $a[$head{het_ratio}];
}
close F;

#Check pedigry of the individuals
open F, "$dir_peddy/$cohort.ped_check.csv" or modules::Exception->throw("Can't open '$dir_peddy/$cohort.ped_check.csv'");
undef %head;
my %pedigree;
while(<F>){
	chomp;
	my @a = split ",";
	if(!%head){
		for(my $i = 0; $i < scalar @a; $i++){
			#sample_a,sample_b,rel,hets_a,hets_b,shared_hets,ibs0,ibs2,n,pedigree_parents,pedigree_relatedness,predicted_parents,parent_error,sample_duplication_error,rel_difference
			$head{$a[$i]} = $i;
		}
		next;
	}
	$pedigree{$a[$head{sample_a}]}{$a[$head{sample_b}]}{rel_expected}   = $a[$head{pedigree_relatedness}];
	$pedigree{$a[$head{sample_b}]}{$a[$head{sample_a}]}{rel_expected}   = $a[$head{pedigree_relatedness}];
	$pedigree{$a[$head{sample_a}]}{$a[$head{sample_b}]}{rel_calculated} = $a[$head{rel}];
	$pedigree{$a[$head{sample_b}]}{$a[$head{sample_a}]}{rel_calculated} = $a[$head{rel}];
	$pedigree{$a[$head{sample_a}]}{$a[$head{sample_b}]}{rel_ok}         = $a[$head{parent_error}] eq 'False'? 'Y': 'N';;
	$pedigree{$a[$head{sample_b}]}{$a[$head{sample_a}]}{rel_ok}         = $a[$head{parent_error}] eq 'False'? 'Y': 'N';;
	$pedigree{$a[$head{sample_a}]}{$a[$head{sample_b}]}{dup_error}      = $a[$head{sample_duplication_error}];
	$pedigree{$a[$head{sample_b}]}{$a[$head{sample_a}]}{dup_error}      = $a[$head{sample_duplication_error}];
}
close F;

my $cohort_data = [
	['PIPELINE RUN', ''],
	['Cohort Name', $cohort],
	['Pipeline Ver. and Run Dir', $Config->read("global", "version")."   $dir_cohort"],
	['Start/Finish Time', "$time_start / $timestamp"],
	['Piper', "$username"]
	#['Operator in Charge', "$username"]
];

my $individual_data = [
	['INDIVIDUALS', '', '', '', ''],
	@ln
];

my $pdf_file = "$dir_run/$cohort\_summary.pdf";
my $pdf = PDF::API2::Simple->new(file => $pdf_file, width => 595, height => 843, margin_left => 56, margin_right => 56, margin_top => 56, margin_bottom => 56, header => \&header, footer => \&footer); 
my $pdftable = new PDF::Table;  
$pdf->add_font('Verdana'); 
$pdf->add_font('Arial'); 
$pdf->add_font('ArialBold'); 

my($final_page, $number_of_pages, $final_y);

# ********* Cohort Summary Page **************
$pdf->add_page();
$pdf->set_font('Arial');
#my $gfx = $pdf->current_page->gfx();
#my $image = $pdf->pdf->image_png("$dir_peddy/$cohort.pca.png");
($final_page, $number_of_pages, $final_y) = table($cohort_data, $pdf->margin_bottom + 710);
#warn "number_of_pages=$number_of_pages, final_y=$final_y, pdf->margin_bottom=".$pdf->margin_bottom."\n";
($final_page, $number_of_pages, $final_y) = table($individual_data, $final_y - 8);
#warn "number_of_pages=$number_of_pages, final_y=$final_y, pdf->margin_bottom=".$pdf->margin_bottom."\n";
warn "image '$dir_peddy/$cohort.pca.png' NOT OK\n" if(! -s "$dir_peddy/$cohort.pca.png");
$pdf->image("$dir_peddy/$cohort.pca.png", x => ($pdf->width / 2) - 225 , y => $final_y - 300 - 8, width => 450, height => 300);
$pdf->rect(x => $pdf->margin_left, y => $final_y - 8, to_x => $pdf->margin_left + $pdf->effective_width, to_y => $final_y - 8 - 300, width => 1, stroke => 'on', stroke_color => 'grey', fill => 'off');
#$gfx->image($image, ($pdf->width / 2) - 150, $final_y - 300 - 5, $image->width, $image->height);

# ********* Sample Summary Pages **************
foreach my $indv(@indv_id){
	$pdf->add_page();
	$pdf->set_font('Arial');

	#record any suspected sample duplications:
	my @dupl;
	foreach my $indv_b(@indv_id){
		push @dupl, ["WARNING: Identical", $indv_b."   either a monozygotic twin or sample duplication" ] if(defined $pedigree{$indv}{$indv_b} && $pedigree{$indv}{$indv_b}{dup_error} eq 'True');
	}

	my @bam_data;
	push @bam_data, ["ALIGNMENT STATS", ''];
	open F, "$dir_bam/$cohort-$indv.duplicatemetrics.txt" or modules::Exception->throw("Can't open '$dir_bam/$cohort-$indv.duplicatemetrics.txt'");
	my $isdata = 0;
	undef %head;
	while(<F>){
		chomp;
		next if(/^\s*$/);
		if(/^## METRICS CLASS/){
			$isdata = 1;
			next;
		}
		next if(!$isdata);
		my @a = split "\t";
		if(!%head){
			for(my $i = 0; $i < scalar @a; $i++){
				#LIBRARY	UNPAIRED_READS_EXAMINED	READ_PAIRS_EXAMINED	SECONDARY_OR_SUPPLEMENTARY_RDS	UNMAPPED_READS	UNPAIRED_READ_DUPLICATES	READ_PAIR_DUPLICATES	
				#READ_PAIR_OPTICAL_DUPLICATES	PERCENT_DUPLICATION	ESTIMATED_LIBRARY_SIZE
				$head{$a[$i]} = $i;
			}
			next;
		}
		else{
			my $nfrag = $a[$head{READ_PAIRS_EXAMINED}] + $a[$head{UNPAIRED_READS_EXAMINED}] / 2 + $a[$head{UNMAPPED_READS}] / 2;
			push @bam_data, ["Number of Processed Read-Pairs", ithf(sprintf("%.0f", $nfrag))];
			push @bam_data, ["Percent of Properly Aligned Read-Pairs", sprintf("%.1f%s", 100 * $a[$head{READ_PAIRS_EXAMINED}] / $nfrag, '%')];
			push @bam_data, ["Percent of Duplication", sprintf("%.1f%s", 100 * $a[$head{PERCENT_DUPLICATION}], '%')];
			last;
		}
	}
	close F;

	open F, "$dir_bam/$cohort-$indv.bammetrics.txt" or modules::Exception->throw("Can't open '$dir_bam/$cohort-$indv.bammetrics.txt'");
	$isdata = 0;
	undef %head;
	while(<F>){
		chomp;
		next if(/^\s*$/);
		if(/^## METRICS CLASS/){
			$isdata = 1;
			next;
		}
		next if(!$isdata);
		my @a = split "\t";
		if(!%head){
			for(my $i = 0; $i < scalar @a; $i++){
				#BAIT_SET	BAIT_TERRITORY	BAIT_DESIGN_EFFICIENCY	ON_BAIT_BASES	NEAR_BAIT_BASES	OFF_BAIT_BASES	PCT_SELECTED_BASES	PCT_OFF_BAIT	ON_BAIT_VS_SELECTED	MEAN_BAIT_COVERAGE	
				#PCT_USABLE_BASES_ON_BAIT	PCT_USABLE_BASES_ON_TARGET	FOLD_ENRICHMENT	HS_LIBRARY_SIZE	HS_PENALTY_10X	HS_PENALTY_20X	HS_PENALTY_30X	HS_PENALTY_40X	HS_PENALTY_50X	
				#HS_PENALTY_100X	TARGET_TERRITORY	GENOME_SIZE	TOTAL_READS	PF_READS	PF_BASES	PF_UNIQUE_READS	PF_UQ_READS_ALIGNED	PF_BASES_ALIGNED	PF_UQ_BASES_ALIGNED	ON_TARGET_BASES	
				#PCT_PF_READS	PCT_PF_UQ_READS	PCT_PF_UQ_READS_ALIGNED	MEAN_TARGET_COVERAGE	MEDIAN_TARGET_COVERAGE	MAX_TARGET_COVERAGE	MIN_TARGET_COVERAGE	ZERO_CVG_TARGETS_PCT	
				#PCT_EXC_DUPE	PCT_EXC_ADAPTER	PCT_EXC_MAPQ	PCT_EXC_BASEQ	PCT_EXC_OVERLAP	PCT_EXC_OFF_TARGET	FOLD_80_BASE_PENALTY	PCT_TARGET_BASES_1X	PCT_TARGET_BASES_2X	PCT_TARGET_BASES_10X	
				#PCT_TARGET_BASES_20X	PCT_TARGET_BASES_30X	PCT_TARGET_BASES_40X	PCT_TARGET_BASES_50X	PCT_TARGET_BASES_100X	AT_DROPOUT	GC_DROPOUT	HET_SNP_SENSITIVITY	HET_SNP_Q	SAMPLE	LIBRARY	READ_GROUP
				$head{$a[$i]} = $i;
			}
			next;
		}
		else{
			push @bam_data, ["WES Bait Regions - Mean Raw Coverage", sprintf("%.1f", $a[$head{MEAN_BAIT_COVERAGE}])];
			push @bam_data, ["Exons - Mean Effective Coverage", sprintf("%.1f", $a[$head{MEAN_TARGET_COVERAGE}])];
			push @bam_data, ["Exons - Percent of Bases With No Coverage", sprintf("%.1f%s", 100 * $a[$head{ZERO_CVG_TARGETS_PCT}], '%')];
			last;
		}
	}
	close F;

	#go through fastq files
	my @fq;
	my $rd = $Config->read($indv);
	foreach my $k(sort keys %{$rd}){
		#warn("$k\n");
		next if($k !~ /^reads/);
		my $fp = $Config->read($indv, $k);
		my @f = split ",", $fp;
		$f[0] = basename($f[0]);
		$f[1] = basename($f[1]);
		push @fq, ['', '', ''] if(@fq); #there is no real header for following fastq files, so at least one empty row to separate
		push @fq, ["Fastq PE Files", @f];
		
		$k =~ s/^reads://;
		open F, "$dir_fastqc/$k.summary.txt" or modules::Exception->throw("Can't open '$dir_fastqc/$k.summary.txt'");
		while(<F>){
			chomp;
			s/Sequences/Seqs./g;
			s/sequences/seqs./g;
			s/sequence/seq./g;
			s/Sequence/Seq./g;
			push @fq, [split "\t"];
		}
		close F;
	}
	
	my $data = [
		["INDIVIDUAL $indv", ''.($indv_data{$indv}{affected} eq 'Y'? '': 'UN').'AFFECTED'],
		["Sex", ($indv_data{$indv}{sex_ped} eq 'M'? 'Male': 'Female')."   confirmed: ".$indv_data{$indv}{sex_ok}."   (heterozygosity of chrX: ".sprintf("%.2f",$indv_data{$indv}{x_het_ratio}).")"],
		["Ancestry", $indv_data{$indv}{ancestry}."   (prediction probability: ".$indv_data{$indv}{ancestry_prob}.")"],
		["Mother", $indv_data{$indv}{mother}.($indv_data{$indv}{mother} eq '-'? '': "   confirmed: ".$pedigree{$indv}{$indv_data{$indv}{mother}}{rel_ok}. "   (rel. expected: ".$pedigree{$indv}{$indv_data{$indv}{mother}}{rel_expected}.", calculated: ".sprintf("%.2f",$pedigree{$indv}{$indv_data{$indv}{mother}}{rel_calculated}).")")],
		["Father", $indv_data{$indv}{father}.($indv_data{$indv}{father} eq '-'? '': "   confirmed: ".$pedigree{$indv}{$indv_data{$indv}{father}}{rel_ok}. "   (rel. expected: ".$pedigree{$indv}{$indv_data{$indv}{father}}{rel_expected}.", calculated: ".sprintf("%.2f",$pedigree{$indv}{$indv_data{$indv}{father}}{rel_calculated}).")")],
		@dupl,
	];
	my ($final_page, $number_of_pages, $final_y) = table($data, $pdf->margin_bottom + 710);
	($final_page, $number_of_pages, $final_y) = table(\@bam_data, $final_y - 8);
	($final_page, $number_of_pages, $final_y) = table(\@fq, $final_y - 8, 8, 2);
}#foreach my $indv(@indv_id)

# ********* Short Variant Summary Page **************
$pdf->add_page();
$pdf->set_font('Arial');

open F, "$dir_vcf/$cohort.stats.tsv" or modules::Exception->throw("Can't open '$dir_vcf/$cohort.stats.tsv'");
my @vcf_data;
undef %head;
push @vcf_data, ["SHORT VARIANT DISCOVERY STATS", "Read Cover Filer >= $filter_rd_cvr", ''];
while(<F>){
	chomp;
	my @a = split "\t";
	if(!%head){
		for(my $i = 0; $i < scalar @a; $i++){
			#bad_cover	bad_cover_coding	indel	indel_coding	known	known_coding	multi	multi_coding	
			#novel	novel_coding	snp	snp_coding	snp_known	snp_known_coding	snp_novel	snp_novel_coding	ti	ti_coding	ti_known	ti_known_coding	ti_novel	ti_novel_coding
			$head{$a[$i]} = $i;
		}
		next;
	}
	else{
		push @vcf_data, ["SNP and INDEL Varians", "Passed Filer: ".ithf($a[$head{snp}] + $a[$head{indel}]),"   Did Not Pass Filter: ".ithf($a[$head{bad_cover}])];
		push @vcf_data, ["SNPs which Passed The Filter:"];
		push @vcf_data, ["   All SNPs", ithf(sprintf("%-9d", $a[$head{snp}])),"   Ti/Tv ratio: ".sprintf("%.2f", $a[$head{ti}] / ($a[$head{snp}] - $a[$head{ti}]))];
		push @vcf_data, ["   Known SNPs", ithf(sprintf("%-9d", $a[$head{snp_known}])),"   Ti/Tv ratio: ".sprintf("%.2f", $a[$head{ti_known}] / ($a[$head{snp_known}] - $a[$head{ti_known}]))];
		push @vcf_data, ["   Novel SNPs", ithf(sprintf("%-9d", $a[$head{snp_novel}])),"   Ti/Tv ratio: ".sprintf("%.2f", $a[$head{ti_novel}] / ($a[$head{snp_novel}] - $a[$head{ti_novel}]))];
		push @vcf_data, ["   Coding SNPs (exons and splice-regions)", ithf(sprintf("%-9d", $a[$head{snp_coding}])),"   Ti/Tv ratio: ".sprintf("%.2f", $a[$head{ti_coding}] / ($a[$head{snp_coding}] - $a[$head{ti_coding}]))];
		push @vcf_data, ["INDELs which Passed The Filter:"];
		push @vcf_data, ["   All INDELs", ithf(sprintf("%-9d", $a[$head{indel}]))];
		push @vcf_data, ["   Coding INDELs (exons and splice-regions)", ithf(sprintf("%-9d", $a[$head{indel_coding}]))];
	}
}
close F;


($final_page, $number_of_pages, $final_y) = table(\@vcf_data, $pdf->margin_bottom + 710);
warn "VQASR tranches image file '$dir_vqsr/$cohort.SNP.all.tranches.png' is empty\n" if(! -s "$dir_vqsr/$cohort.SNP.all.tranches.png");
$pdf->image("$dir_vqsr/$cohort.SNP.all.tranches.png", x => ($pdf->width / 2) - 225 , y => $final_y - 300 - 8, width => 450, height => 300);
$pdf->rect(x => $pdf->margin_left, y => $final_y - 8, to_x => $pdf->margin_left + $pdf->effective_width, to_y => $final_y - 8 - 300, width => 1, stroke => 'on', stroke_color => 'grey', fill => 'off');

# ********* Copy Number Variant Summary Page **************
$pdf->add_page();
$pdf->set_font('Arial');

my $n_cnv_all    = `zcat $dir_cnv/$cohort.cnv.vep_all.tsv.gz| wc -l`;
my $n_cnv_coding = `zcat $dir_cnv/$cohort.cnv.vep_coding.tsv.gz| wc -l`;
$n_cnv_all--;
$n_cnv_coding--;

my @cnv_data;
push @cnv_data, ["COPY NUMBER VARIANT DISCOVERY STATS", ''];
push @cnv_data, ["All Variants", ithf(sprintf("%-9d", $n_cnv_all))];
push @cnv_data, ["Coding Variants (exons and splice-regions)", ithf(sprintf("%-9d", $n_cnv_coding))];
($final_page, $number_of_pages, $final_y) = table(\@cnv_data, $pdf->margin_bottom + 710);

my @ploidy_data;
my @ploidy;
push @ploidy_data, ["Chromosomal Ploidy"];
($final_page, $number_of_pages, $final_y) = table(\@ploidy_data, $final_y - 8);

my %cnv_model_ploidy;
open F, "cat $cnv_model_calls/SAMPLE_*/contig_ploidy.tsv | grep -vP \"^(\@)|(CONTIG)\" |" or modules::Exception->throw("Can't open 'cat $cnv_model_calls/SAMPLE_*/contig_ploidy.tsv | grep -vP \"^(\@)|(CONTIG)\" |'");
while(<F>){
	chomp;
	my @a = split "\t";
	$cnv_model_ploidy{"$a[0]-$a[1]"}{gq} += $a[2];
	$cnv_model_ploidy{"$a[0]-$a[1]"}{n}++;
}
close F;
foreach(keys %cnv_model_ploidy){
	$cnv_model_ploidy{$_}{mean} = sprintf("%.2f", $cnv_model_ploidy{$_}{gq} / $cnv_model_ploidy{$_}{n});
}

foreach my $indv(@indv_id){
	open F, "$dir_ploidy/$cohort-$indv\_ploidy-calls/SAMPLE_0/contig_ploidy.tsv" or modules::Exception->throw("Can't open '$dir_ploidy/$cohort-$indv\_ploidy-calls/SAMPLE_0/contig_ploidy.tsv'");
	<F>;<F>;
	my $cnt = 0;
	push @ploidy_data, ["$indv", '', '', '', '', '', '', '', ''];
	while(<F>){
		chomp;
		$cnt++;
		my @a = split "\t";
		my $gqr = defined $cnv_model_ploidy{"$a[0]-$a[1]"}? sprintf("%.2f", $a[2] / $cnv_model_ploidy{"$a[0]-$a[1]"}{mean}): 'NA';
		push @ploidy, sprintf("%-6s: %2s %s%s", $a[0], $a[1], chr(0x00A0)x2, $gqr);
		#push @ploidy, sprintf("%-6s: %2s %".chr(0x00A0)."6s", $a[0], $a[1], $gqr);
		if(!($cnt % 8)){
			push @ploidy_data, ['', @ploidy];
			undef @ploidy;
		}
	}
	close F;
	($final_page, $number_of_pages, $final_y) = table(\@ploidy_data, $final_y - 2);
	undef @ploidy_data;
}#foreach

# ********* Tools Summary Page **************
$pdf->add_page();
$pdf->set_font('Arial');

my @tools_data;
push @tools_data, ['SOFTWARE', ''];
my $Tools = $Config->read("tool_versions");
foreach my $tool(sort keys %{$Tools}){
	my $cmd = $Config->read("tool_versions", "$tool");
	my $ver = `$cmd`;
	chomp $ver;
	#warn "$tool: $ver\n";
	push @tools_data, [$tool, $ver]
}

my @db_data;
push @db_data, ['DATABASES', ''];
my $Db = $Config->read("db_versions");
foreach my $db(sort keys %{$Db}){
	my $ver = $Config->read("db_versions", "$db");
	chomp $ver;
	#warn "$db: $ver\n";
	push @db_data, [$db, $ver]
}

($final_page, $number_of_pages, $final_y) = table(\@tools_data, $pdf->margin_bottom + 710);
($final_page, $number_of_pages, $final_y) = table(\@db_data, $final_y - 8);

# ********* Pipeline Steps Summary Page **************
$pdf->add_page();
$pdf->set_font('Arial');

my @step_data;
push @step_data, ['PIPELINE STEPS', ''];
foreach(@{$Pipeline->pipesteps}){
	#warn "step: $_->[0] $_->[1]\n";
	push @step_data, [$_->[0], $_->[1]];
}

($final_page, $number_of_pages, $final_y) = table(\@step_data, $pdf->margin_bottom + 710);

$pdf->save();

#link in results:
modules::Utils::lns("$dir_run/$cohort\_summary.pdf", "$dir_result/$cohort\_summary.pdf");

exit(0);

sub table{
	my($data, $y, $font_size, $padding, $head_cell_props) = @_;

	$font_size = 10 if(!defined $font_size);
	$padding = 3 if(!defined $padding);
	
	return $pdftable->table(
		$pdf->pdf, 
		$pdf->current_page, 
		$data, 
		x => $pdf->margin_left, 
		w => $pdf->effective_width, 
		#start_y => $pdf->margin_bottom + 710 - $y, 
		start_y => $y, 
		next_y  => 780,
		start_h => 500, 
		next_h  => 710,
		header_props => {
			font => $pdf->current_font, 
			font_size => $font_size, 
			font_color => '#000000', 
			#bg_color => '#FF9046', 
			bg_color => 'grey',
			repeat => 0
		}, 
		font => $pdf->current_font,
		font_size => $font_size, 
		padding => $padding, 
		padding_right => 10,
		border => 1,
		border_color => 'grey'
	);  
}#table

sub header{ 
	my $strokecolor = $pdf->strokecolor; 
	my $y = $pdf->height - $pdf->margin_top; 
	my $x = ($pdf->width / 2);  
	$pdf->stroke_color('#555555'); 
	$pdf->next_line; 
	$pdf->set_font('Arial', 8); 
	$pdf->text("Summary Report for Cohort $cohort", x => $x, y => $y, font_size => 10, align =>'center'); 
	$pdf->y($pdf->y - 5); 
}#header
  
sub footer{ 
	my $strokecol = $pdf->strokecolor; 
	$pdf->stroke_color('grey'); 
	$pdf->line(x => $pdf->margin_left, y => 50, to_x => $pdf->margin_left + $pdf->effective_width, to_y => 50, stroke => 'on', fill => 'off', width => 1); 
	my $fillcolor = $pdf->fill_color; 
	my $font = $pdf->current_font; 
	$pdf->fill_color('#000000'); 
	$pdf->set_font('Arial', 8); 
	$pdf->text($timestamp, x => $pdf->margin_left, y => 40, font_size => 9, align => 'left' ); 
	$pdf->text( "- page $page_num -", x => $pdf->width / 2, y => 30, font_size => 9, align => 'center'); 
	$page_num++
}#footer

sub ithf{
	my $v = shift;
	$v = reverse($v);
	$v =~ s/(\d{3})/$1,/g;
	$v = reverse($v);
	$v =~ s/^,//;
	return $v;
}

END{
	warn "done script ".basename(__FILE__)."\n"
}
