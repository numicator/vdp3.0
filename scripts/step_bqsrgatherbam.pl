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

my $dir_cohort = $Config->read("cohort", "dir");
modules::Exception->throw("Can't access cohort directory $dir_cohort") if(!-d $dir_cohort);

my $dir_run = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:$step", "dir");
modules::Exception->throw("Can't access cohort run directory $dir_run") if(!-d $dir_run);
my $dir_tmp = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("directories", "tmp");
modules::Exception->throw("Can't access cohort run TEMP directory $dir_tmp") if(!-d $dir_tmp);
my $dir_bqsr = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:split:bqsr_apply", "dir");;
modules::Exception->throw("Can't access cohort run directory $dir_bqsr") if(!-d $dir_bqsr);

my @files;
foreach(sort keys %{$Config->read("split")}){
	my $f = "$dir_bqsr/$cohort-$individual.$_.bqsr.bam";
	modules::Exception->throw("Can't access file '$f'") if(!-e $f);
	modules::Exception->throw("File '$f' is empty") if(!-s $f);
	push @files, $f;
}

my $PED = modules::PED->new("$dir_cohort/$cohort.pedx");
modules::Exception->throw("cohort PED file must contain exactly one family") if(scalar keys %{$PED->ped} != 1);
modules::Exception->throw("cohort id submited as argument is not the same as cohort id in PED: '$cohort' ne '".(keys %{$PED->ped})[0]."'") if((keys %{$PED->ped})[0] ne $cohort);
#my $Cohort = modules::Cohort->new("$cohort", $Config, $PED);
#$Cohort->add_individuals_ped();
#my $Pipeline = modules::Pipeline->new(cohort => $Cohort);
#$Pipeline->get_pipesteps;
#$Pipeline->get_qjobs;

my $reference     = $Config->read("references", "genome_fasta");
my $region_bait   = $Config->read("targets", "hs_bait");
my $region_target = $Config->read("targets", "hs_target");

my $cmd_m = $Config->read("step:$step", "picard_merge_bin");
my $cmd_s = $Config->read("step:$step", "picard_sort_bin");
my $cmd_x = $Config->read("step:$step", "picard_metrics_bin");

my $cmd = "$cmd_m INPUT=".join(" INPUT=", @files)." OUTPUT=/dev/stdout | $cmd_s MAX_RECORDS_IN_RAM=300000 INPUT=/dev/stdin OUTPUT=$dir_run/$cohort-$individual.bqsr.bam SORT_ORDER=coordinate CREATE_INDEX=true";
#warn "$cmd\n"; exit(PIPE_NO_PROGRESS);
#my $r = $Syscall->run($cmd);
my $r;
exit(1) if($r);

$cmd = "$cmd_x TMP_DIR=$dir_tmp I=$dir_run/$cohort-$individual.bqsr.bam O=$dir_run/$cohort-$individual.bammetrics.txt R=$reference BAIT_INTERVALS=$region_bait TARGET_INTERVALS=$region_target PER_TARGET_COVERAGE=$dir_run/$cohort-$individual.exon_cover.tsv";
$r = $Syscall->run($cmd);
exit(1) if($r);

exit(0);

END{
	warn "done script ".basename(__FILE__)."\n"
}
