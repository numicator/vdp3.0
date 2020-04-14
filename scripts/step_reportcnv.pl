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
my $dir_result = $dir_cohort.'/'.$Config->read("directories", "result");
modules::Exception->throw("Can't access cohort run directory $dir_result") if(!-d $dir_result);
my $dir_tmp = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("directories", "tmp");
modules::Exception->throw("Can't access cohort run TEMP directory $dir_tmp") if(!-d $dir_tmp);
my $dir_vcf = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:gatk_cnv_gather_calls", "dir");
modules::Exception->throw("Can't access cohort run directory $dir_vcf") if(!-d $dir_vcf);

my $PED = modules::PED->new("$dir_cohort/$cohort.pedx");
modules::Exception->throw("cohort PED file must contain exactly one family") if(scalar keys %{$PED->ped} != 1);
modules::Exception->throw("cohort id submited as argument is not the same as cohort id in PED: '$cohort' ne '".(keys %{$PED->ped})[0]."'") if((keys %{$PED->ped})[0] ne $cohort);
my $Cohort = modules::Cohort->new("$cohort", $Config, $PED);
$Cohort->add_individuals_ped();
#my $Pipeline = modules::Pipeline->new(cohort => $Cohort);
#$Pipeline->get_pipesteps;
#$Pipeline->get_qjobs;

my $index_dir    = $Config->read("directories", "vep_index");
my $fasta        = $Config->read("step:$step", "fasta");


my $bgzip_bin = $Config->read("step:$step", "bgzip_bin");
my $tabix_bin = $Config->read("step:$step", "tabix_bin");
my $vep_bin   = $Config->read("step:$step", "vep_bin");

my @files;
foreach(sort @{$Cohort->individual}){
	my $indv = $_->id;
	my $f = "$dir_vcf/$cohort-$indv\_intervals.vcf.gz";
	modules::Exception->throw("Can't access file '$f'") if(!-e $f);
	modules::Exception->throw("File '$f' is empty") if(!-s $f);
	push @files, $f;
}

my $header;
my %vcf;
my @sample;
for(my $i = 0; $i < scalar @files; $i++){
	my $fname = $files[$i];
	open I, "$bgzip_bin -dc $fname|" or modules::Exception->throw("Can't do: '$bgzip_bin -dc $fname|'");
	#warn "start $fname\n";
	my $inx = 0; #lame but effective, need for sorting
	my $smpl;
	while(<I>){
		if(!$i && /^##/){
			$header .= $_;
			next;
		}
		chomp;
		#warn "$_\n";
		my @a = split "\t";
		if(!$i && /^#CHROM/){
			$header .= join("\t", @a[0..8]);
		}
		if(/^#CHROM/){
			$smpl = $a[9];
			warn "  $smpl\n";
			push @sample, $smpl;
			next;
		}
		next if(/^#/);
		modules::Exception->throw("Sample symbol must be know at this point") if(!defined $smpl);
		$vcf{$a[2]}{__vcf_inx__} = $inx++;
		$vcf{$a[2]}{__vcf_data__} = join("\t", @a[0..8]);
		$vcf{$a[2]}{$smpl} = $a[9];
	}
	#warn "done $fname\n";
	close I;
}
@sample = sort @sample;
$header .= "\t".join("\t", @sample)."\n";

open O, "| $bgzip_bin -c >$dir_run/$cohort.cnv.vcf.gz" or modules::Exception->throw("Can't open '| $bgzip_bin -c >$dir_run/$cohort.cnv.vcf.gz'");
print O $header;
foreach my $rec(sort{$vcf{$a}{__vcf_inx__} <=> $vcf{$b}{__vcf_inx__}} keys %vcf){
	my $v = 0;
	foreach my $smpl(@sample){
		my @a = split ":", $vcf{$rec}{$smpl};
		$v++ if($a[0] != 0);
	}
	#report only sites which are variant in at least one sample
	if($v){
		print O $vcf{$rec}{__vcf_data__};
		foreach my $smpl(@sample){
			print O "\t$vcf{$rec}{$smpl}";
		}
		print O "\n";
	}
}
close O;
my $cmd;
my $r;
$cmd = "$tabix_bin -f $dir_run/$cohort.cnv.vcf.gz";
#$r = $Syscall->run($cmd);
exit(1) if($r);

warn "running VEP on $dir_run/$cohort.cnv.vcf.gz\n";
$cmd = "--force_overwrite --cache --offline --species homo_sapiens --merged --fork 1 --biotype --regulatory --hgvs --numbers --symbol --canonical --flag_pick --vcf --use_transcript_ref --dir $index_dir --fasta $fasta --I $dir_run/$cohort.cnv.vcf.gz --stats_text --stats_file $dir_run/$cohort.cnv.vep_stats.txt -o stdout | $bgzip_bin -c >$dir_run/$cohort.cnv.vep.vcf.gz";
$cmd =~ s/\s+-/ \\\n  -/g;
$cmd = "$vep_bin $cmd";
#$r = $Syscall->run($cmd);
exit(1) if($r);
warn "done VEP on $dir_run/$cohort.cnv.vcf.gz\n";

open I, "$bgzip_bin -dc $dir_run/$cohort.cnv.vep.vcf.gz|" or modules::Exception->throw("Can't do: '$bgzip_bin -dc $dir_run/$cohort.cnv.vep.vcf.gz|'");
open O, ">$dir_run/$cohort.cnv.vep.tsv" or modules::Exception->throw("Can't open '$dir_run/$cohort.cnv.vep.tsv' for writing");
my %vepfld;
my %sampcln;
my $header_vep;

while(<I>){
	chomp;
	if(/^##INFO=<ID=CSQ,/){ ##INFO=<ID=CSQ,Number=.,Type=String,Description="Consequence annotations from Ensembl VEP. Format: Allele|Consequence|IMPACT|SYMBOL|Gene|Feature_type|Feature|BIOTYPE|EXON|INTRON|HGVSc|HGVSp|cDNA_position|CDS_position|Protein_position|Amino_acids|Codons|Existing_variation|DISTANCE|STRAND|FLAGS|PICK|SYMBOL_SOURCE|HGNC_ID|CANONICAL|REFSEQ_MATCH|SOURCE|GIVEN_REF|USED_REF|BAM_EDIT|HGVS_OFFSET|MOTIF_NAME|MOTIF_POS|HIGH_INF_POS|MOTIF_SCORE_CHANGE">
		s/^.+Ensembl VEP. Format: //;
		s/\">\s*$//;
		#Allele|Consequence|IMPACT|SYMBOL|Gene|Feature_type|Feature|BIOTYPE|EXON|INTRON|HGVSc|HGVSp|cDNA_position|CDS_position|Protein_position|Amino_acids|Codons|Existing_variation|DISTANCE|STRAND|FLAGS|PICK|SYMBOL_SOURCE|HGNC_ID|CANONICAL|REFSEQ_MATCH|SOURCE|GIVEN_REF|USED_REF|BAM_EDIT|HGVS_OFFSET|MOTIF_NAME|MOTIF_POS|HIGH_INF_POS|MOTIF_SCORE_CHANGE
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
		print O "chr\tpos\tref\tevent";
		foreach(sort{$sampcln{$a} <=> $sampcln{$b}} keys %sampcln){
			print O "\t$_-GT";
		}
		foreach(sort{$sampcln{$a} <=> $sampcln{$b}} keys %sampcln){
			print O "\t$_-CN";
		}
		foreach(sort{$sampcln{$a} <=> $sampcln{$b}} keys %sampcln){
			print O "\t$_-CNQ";
		}
		foreach(sort{$sampcln{$a} <=> $sampcln{$b}} keys %sampcln){
			print O "\t$_-CNLP";
		}
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
	my @cn;
	my @cnq;
	my @cnlp;
	foreach(sort{$sampcln{$a} <=> $sampcln{$b}} keys %sampcln){
		my @a = split(':', $fld[$sampcln{$_}]);
		push @gt,   $a[$frmtag{GT}];
		push @cn,   $a[$frmtag{CN}];
		push @cnq,  $a[$frmtag{CNQ}];
		push @cnlp, $a[$frmtag{CNLP}];
	}

	my $csq = '';
	$csq = $1 if($fld[7] =~ /CSQ=([^\;]+)/);
	$csq =~ s/\|/\t/g;
	my @csqs = split ",", $csq;
	for(my $i = 0; $i < scalar @csqs; $i++){
		$csqs[$i] =~ s/\&/,/g;
		my @a = split "\t", $csqs[$i];
		if(defined $a[$vepfld{PICK}] && $a[$vepfld{PICK}] ne '' && $a[$vepfld{PICK}] == 1){
			print O join("\t", $fld[0], $fld[1], $fld[3], $fld[4])."\t".join("\t", @gt)."\t".join("\t", @cn)."\t".join("\t", @cnq)."\t".join("\t", @cnlp);
			print O "\t$csqs[$i]\n";
		}
	}
}
close O;
close I;

#link in results:
#VCF no VEP annotation
#modules::Utils::lns("$dir_run/$cohort.vcf.gz", "$dir_result/$cohort.vcf.gz");
#modules::Utils::lns("$dir_run/$cohort.vcf.gz.tbi", "$dir_result/$cohort.vcf.gz.tbi");
#TSV report complete, all variants
#modules::Utils::lns("$dir_run/$cohort.vep_all.tsv.gz", "$dir_result/$cohort.vep_all.tsv.gz");
#modules::Utils::lns("$dir_run/$cohort.vep_all.tsv.gz.tbi", "$dir_result/$cohort.vep_all.tsv.gz.tbi");
#TSV report coding, only variants affecting coding sequence - exonic and splice-regions
#modules::Utils::lns("$dir_run/$cohort.vep_coding.tsv.gz", "$dir_result/$cohort.vep_coding.tsv.gz");
#modules::Utils::lns("$dir_run/$cohort.vep_coding.tsv.gz.tbi", "$dir_result/$cohort.vep_coding.tsv.gz.tbi");

exit(0);

END{
	warn "done script ".basename(__FILE__)."\n"
}
