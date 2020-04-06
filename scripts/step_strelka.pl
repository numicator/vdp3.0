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
my $dir_bam = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:merge_bam", "dir");
modules::Exception->throw("Can't access cohort run directory $dir_bam") if(!-d $dir_bam);
my $regions = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:merge_target", "dir").'/regions.bed';
modules::Exception->throw("Can't access call regions file $regions") if(!-e $regions);
my $samples = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:merge_target", "dir").'/samples.txt';
modules::Exception->throw("Can't access samples list file $samples") if(!-e $samples);

my $split_bed = $Config->read($Config->read("split", $split), "bed");

my $PED = modules::PED->new("$dir_cohort/$cohort.pedx");
modules::Exception->throw("cohort PED file must contain exactly one family") if(scalar keys %{$PED->ped} != 1);
modules::Exception->throw("cohort id submited as argument is not the same as cohort id in PED: '$cohort' ne '".(keys %{$PED->ped})[0]."'") if((keys %{$PED->ped})[0] ne $cohort);
#my $Cohort = modules::Cohort->new("$cohort", $Config, $PED);
#$Cohort->add_individuals_ped();
#my $Pipeline = modules::Pipeline->new(cohort => $Cohort);
#$Pipeline->get_pipesteps;
#$Pipeline->get_qjobs;

my $reference = $Config->read("references", "genome_fasta");

#my $read_filter = $Config->read("step:$step", "read_filter_add");

my @bams;
open F, "$samples" or modules::Exception->throw("Can't open $samples for reading\n");
while(<F>){
	chomp;
	push @bams, "$cohort-$_.$split.bam";
}
close F;

remove_tree("$dir_run/$split");
make_path("$dir_run/$split");

#prepare merged bad with split and calling regions:
my $cmd = $Config->read("step:$step", "bedtools_bin");
my $cmd_bgzip = $Config->read("step:$step", "bgzip_bin");
my $cmd_bcftools = $Config->read("step:$step", "bcftools_bin");
my $cmd_tabix = $Config->read("step:$step", "tabix_bin");
my $bedsplit = $Config->read($Config->read("split", "$split"), "bed");
$cmd = "$cmd intersect -a $regions -b $bedsplit | $cmd_bgzip -c >$dir_run/$split/regions.$split.bed.gz";
my $r = $Syscall->run($cmd);
exit(1) if($r);
$cmd = "$cmd_tabix -f $dir_run/$split/regions.$split.bed.gz";
$r = $Syscall->run($cmd);
exit(1) if($r);
$regions = "$dir_run/$split/regions.$split.bed.gz";

#configure strelka run:
$cmd = $Config->read("step:$step", "config_bin");
my $cmdx .= " --referenceFasta=$reference --callRegions $regions --exome --bam=$dir_bam/".join(" --bam=$dir_bam/", @bams)." --runDir=$dir_run/$split";
$cmdx =~ s/\s+-/ \\\n  -/g;
$cmd .= $cmdx;
#warn "$cmd\n"; exit(PIPE_NO_PROGRESS);
$r = $Syscall->run($cmd);
exit(1) if($r);

#run strelka workflow (on max number of available CPUs):
#my $ncpu = $Config->read("step:$step", "pbs_ncpus");
#$cmd = "$dir_run/$split/runWorkflow.py --quiet -m local -j $ncpu";
$cmd = "$dir_run/$split/runWorkflow.py --quiet -m local";
#warn "$cmd\n"; exit(PIPE_NO_PROGRESS);
$r = $Syscall->run($cmd);
exit(1) if($r);

#check workflow output:
if(! -e "$dir_run/$split/workflow.exitcode.txt"){
	warn "missing workflow exit code file '$dir_run/$split/workflow.exitcode.txt'";
	exit(1);
}
$r = `cat $dir_run/$split/workflow.exitcode.txt`;
chomp $r;
warn "workflow exit code: '$r'";
exit(1) if(!defined $r || $r !~ /^\d+$/ || $r != 0);

#get final variant file:
if(! -e "$dir_run/$split/results/variants/variants.vcf.gz"){
	warn "missing VCF file '$dir_run/$split/results/variants/variants.vcf.gz'";
	exit(1);
}

$cmd = "$cmd_bcftools view -f PASS -O z $dir_run/$split/results/variants/variants.vcf.gz -o $dir_run/$cohort.$split.vcf.gz";
$r = $Syscall->run($cmd);
exit(1) if($r);
$cmd = "$cmd_tabix -f $dir_run/$cohort.$split.vcf.gz";
$r = $Syscall->run($cmd);
exit(1) if($r);

exit(0);

END{
	warn "done script ".basename(__FILE__)."\n"
}

#other arguments used in Matt pipeline:
#--min-pruning 3 --max-num-haplotypes-in-population 200 --max-alternate-alleles 3 -contamination 0.0

#suggested in other places:
#--minimum-mapping-quality 30