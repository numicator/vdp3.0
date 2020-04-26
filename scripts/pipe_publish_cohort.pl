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
	   		"cohort=s",
	   		"unpublish"
	   		);
	   		
pod2usage(-verbose => 2) if $OPT{man};
pod2usage(1) if ($OPT{help});

	   
=pod

=head1 SYNOPSIS

pipe_apfimport.pl

Required flags: NONE

=head1 OPTIONS

    -help  brief help message
    -man   full documentation

=head1 NAME

pipe_publish_cohort.pl -> Does something useful

=head1 DESCRIPTION

April 2020

a script that ...

=head1 AUTHOR

Marcin Adamski

=head1 EXAMPLE

./pipe_publish_cohort.pl

=cut

my $confdir = modules::Utils::confdir;
modules::Exception->throw("Can't access configuration file '$confdir/pipeline.cnf'") if(!-f "$confdir/pipeline.cnf");
my $Config   = modules::Config->new("$confdir/pipeline.cnf");
my $Syscall  = modules::SystemCall->new();

my $pversion    = $Config->read("global", "version");
my $codebase    = $Config->read("directories", "pipeline");
my $dir_cohorts = $Config->read("directories", "work");
warn "pipeline version: '$pversion', codebase: '$codebase'\n";

modules::Exception->throw("mandatory argument '--cohort <cohort-id>' was not specified") if(!defined $OPT{cohort});
my $cohort = $OPT{cohort};
my $unpublish = $OPT{unpublish};

my $Pipeline = modules::Pipeline->new(config => $Config);

my $dir_cohort .= "$dir_cohorts/$cohort";
if($unpublish){
	warn "removing record ".COHORT_RUN_PUBLISHED." for cohort '$cohort'\n";
}
else
{
	warn "adding record ".COHORT_RUN_PUBLISHED." for cohort '$cohort'\n";
}
modules::Exception->throw("Can't access cohort directory $dir_cohort") if(!-d $dir_cohort);
$Config = modules::Config->new("$dir_cohort/pipeline.cnf");
modules::Exception->throw("Cohort directory '$dir_cohort' is not the same as '".$Config->read("cohort", "dir")."' in $dir_cohort/pipeline.cnf, section '[cohort]', value 'dir'") if($Config->read("cohort", "dir") !~ /$dir_cohort\/?/);

my $PED = modules::PED->new("$dir_cohort/$cohort.pedx");
modules::Exception->throw("cohort PED file must contain exactly one family") if(scalar keys %{$PED->ped} != 1);
modules::Exception->throw("cohort id submited as argument is not the same as cohort id in PED: '$cohort' ne '".(keys %{$PED->ped})[0]."'") if((keys %{$PED->ped})[0] ne $cohort);

my $Cohort = modules::Cohort->new("$cohort", $Config, $PED);
if(!$Cohort->has_completed){
	warn "cohort '$cohort' has not yet completed the pipeline, exiting\n";
	exit 0;
}
$Cohort->add_individuals_ped();
$Pipeline->set_cohort(cohort => $Cohort);
$Pipeline->database_lock;
if($unpublish){
	$Pipeline->database_rm_record(COHORT_RUN_PUBLISHED)
}
else{
	$Pipeline->database_record(COHORT_RUN_PUBLISHED)
}

END{
	$Pipeline->database_unlock;
	warn "done script ".basename(__FILE__)."\n"
}
