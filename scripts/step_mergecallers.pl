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

my $dir_gatkhc = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:split:gatk_vqsr_apply_snp", "dir");
modules::Exception->throw("Can't access cohort run directory $dir_gatkhc") if(!-d $dir_gatkhc);

my $dir_varscan = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:split:varscan_snp", "dir");
modules::Exception->throw("Can't access cohort run directory $dir_varscan") if(!-d $dir_varscan);

my $dir_strelka = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:split:strelka", "dir");
modules::Exception->throw("Can't access cohort run directory $dir_strelka") if(!-d $dir_strelka);

my $split_bed = $Config->read($Config->read("split", $split), "bed");

my $PED = modules::PED->new("$dir_cohort/$cohort.ped");
modules::Exception->throw("cohort PED file must contain exactly one family") if(scalar keys %{$PED->ped} != 1);
modules::Exception->throw("cohort id submited as argument is not the same as cohort id in PED: '$cohort' ne '".(keys %{$PED->ped})[0]."'") if((keys %{$PED->ped})[0] ne $cohort);
#my $Cohort = modules::Cohort->new("$cohort", $Config, $PED);
#$Cohort->add_individuals_ped();
#my $Pipeline = modules::Pipeline->new(cohort => $Cohort);
#$Pipeline->get_pipesteps;
#$Pipeline->get_qjobs;

my $bgzip_bin = $Config->read("step:$step", "bgzip_bin");
my $bcftools_bin = $Config->read("step:$step", "bcftools_bin");
my $tabix_bin = $Config->read("step:$step", "tabix_bin");
my $cmdx;

#We will have three (well... four) categories of calls:
#1 - all calls made by GATK HC
#2 - calls made be strelka and varscan but not GATK HC
#3a - calls made by strelka but not found in any other
#3b - calls made by varscan but not found in any other

my($cmd, $str_read, $fout, $caller);

#category 1:
#all we need is to add INFO tag specifying the caller
$caller   = "gatk_hc";
$str_read = "$bgzip_bin -d -c $dir_gatkhc/$cohort.$split.vqsr.vcf.gz|";
$fout     = "$dir_run/$cohort.$caller.$split.vcf.gz";
annotate($str_read, $fout, $caller);

#category 2:
#we need to intersect calls NOT IN gatk_hs, IN strelka, IN varscan (n~011 -w 2)
$caller   = "strelka+varscan";
$str_read = "$bcftools_bin isec -c both -n~011 -w 2 $dir_gatkhc/$cohort.$split.vqsr.vcf.gz $dir_strelka/$cohort.$split.vcf.gz $dir_varscan/$cohort.$split.vcf.gz|";
$fout     = "$dir_run/$cohort.$caller.$split.vcf.gz";
annotate($str_read, $fout, $caller);

#category 3a:
#we need to intersect calls NOT IN gatk_hs, IN strelka, NOT IN varscan (n~010 -w 2)
$caller   = "strelka";
$str_read = "$bcftools_bin isec -c both -n~010 -w 2 $dir_gatkhc/$cohort.$split.vqsr.vcf.gz $dir_strelka/$cohort.$split.vcf.gz $dir_varscan/$cohort.$split.vcf.gz|";
$fout     = "$dir_run/$cohort.$caller.$split.vcf.gz";
annotate($str_read, $fout, $caller);

#category 3b:
#we need to intersect calls NOT IN gatk_hs, NOT IN strelka, IN varscan (n~001 -w 3)
$caller    = "varscan";
$str_read  = "$bcftools_bin isec -c both -n~001 -w 3 $dir_gatkhc/$cohort.$split.vqsr.vcf.gz $dir_strelka/$cohort.$split.vcf.gz $dir_varscan/$cohort.$split.vcf.gz|";
$fout      = "$dir_run/$cohort.$caller.$split.vcf.gz";
annotate($str_read, $fout, $caller);
#warn "STOP"; exit(PIPE_NO_PROGRESS);

#we need to concatenate them all:
$cmd = "$bcftools_bin concat -a $dir_run/$cohort.gatk_hc.$split.vcf.gz $dir_run/$cohort.strelka+varscan.$split.vcf.gz $dir_run/$cohort.strelka.$split.vcf.gz $dir_run/$cohort.varscan.$split.vcf.gz | $bgzip_bin -c >$dir_run/$cohort.$split.vcf.gz";
my $r = $Syscall->run($cmd);
exit(1) if($r);

$cmd = "$tabix_bin -f $dir_run/$cohort.$split.vcf.gz";
$r = $Syscall->run($cmd);
exit(1) if($r);
exit(0);

END{
	warn "done script ".basename(__FILE__)."\n"
}

sub annotate{
	my($str_in, $fout, $caller) = @_;
	
	#I couldn't find a way to do such a simple annotation with bcftools or picard, so wrote this to add tag 'caller' to the INFO column:
	open I, "$str_in" or modules::Exception->throw("Can't do: '$str_in'");
	open O, "|$bgzip_bin -c >$fout" or modules::Exception->throw("Can't do: '|$bgzip_bin -c >$fout'");
	my $info = 7; #index of the INFO column
	my $head_info_line;
	my $head_info_added;
	while(<I>){
		if(/^##INFO=/){
			$head_info_line = $.;
			print O $_;
			next;
		}
		if(!$head_info_added && (defined $head_info_line ||	/^#CHROM/)){ #paste the new INFO after the last one or before the #CHROM line if no INFO defs
			print O "##INFO=<ID=caller,Number=1,Type=String,Description=\"Name of the caller, may be: gatk_hc strelka+varscan strelka varscan\">\n";
			print O $_;
			undef $head_info_line;
			$head_info_added = 1;
			next;
		}
		if(/^#/){
			print O $_;
			next;
		}
		#here we get the real records:
		my @fld = split "\t";
		$fld[$info] = "caller=$caller;$fld[$info]";
		print O join("\t", @fld);
	}
	close O;
	close I;
	
	$cmd = "$tabix_bin -f $fout";
	$r = $Syscall->run($cmd);
	exit(1) if($r);
}#annotate