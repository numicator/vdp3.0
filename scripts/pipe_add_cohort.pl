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

use vars qw(%OPT);


GetOptions(\%OPT, 
	   		"help|h",
	   		"man|m",
	   		"cohort=s",
	   		"overwrite",
	   		"submit",
	   		);
	   		
pod2usage(-verbose => 2) if $OPT{man};
pod2usage(1) if ($OPT{help});

	   
=pod

=head1 SYNOPSIS

process_samples.pl 

Required flags: NONE

=head1 OPTIONS

    -help  brief help message
    -man   full documentation

=head1 NAME

pipe_add_cohort.pl -> Does something useful

=head1 DESCRIPTION

Fab 2020

a script that ...

=head1 AUTHOR

Marcin Adamski

=head1 EXAMPLE

./pipe_add_cohort.pl

=cut
END{warn "done script ".basename(__FILE__)."\n"}

my $confdir = modules::Utils::confdir;
modules::Exception->throw("Can't access configuration file '$confdir/pipeline.cnf'") if(!-f "$confdir/pipeline.cnf");
my $Config   = modules::Config->new("$confdir/pipeline.cnf");
my $Syscall  = modules::SystemCall->new();

my $pversion   = $Config->read("global", "version");
my $dir_reads  = $Config->read("directories", "reads");
my $codebase   = $Config->read("directories", "pipeline");
warn "pipeline version: '$pversion', codebase: '$codebase'\n";

modules::Exception->throw("Missing mandatory argument 'cohort'") if(!defined $OPT{cohort});
my $cohort = $OPT{cohort};
$dir_reads .= "/$cohort";
modules::Exception->throw("Can't access reads directory $dir_reads") if(!-d $dir_reads);
#warn "cohort read directory: $dir_reads\n";

my $PED = modules::PED->new("$dir_reads/$cohort.ped");
modules::Exception->throw("cohort PED file must contain exactly one family") if(scalar keys %{$PED->ped} != 1);
modules::Exception->throw("cohort id submited as argument is not the same as cohort id in PED: '$cohort' ne '".(keys %{$PED->ped})[0]."'") if((keys %{$PED->ped})[0] ne $cohort);
warn "processing cohort '$cohort'\n";

my $Cohort = modules::Cohort->new("$cohort", $Config, $PED);
$Cohort->make_workdir($OPT{overwrite});
$Cohort->add_individuals_ped;
#$Cohort->config_add_readfiles if($OPT{overwrite});
$Cohort->config_add_readfiles;

my $Pipeline = modules::Pipeline->new(cohort => $Cohort);
$Pipeline->get_pipesteps;
#$Pipeline->make_qsubs($OPT{overwrite});
$Pipeline->make_qsubs(1);
$Pipeline->config->reload;
#$Pipeline->config_add_steps();

if(defined $OPT{submit}){
	warn "starting the pipeline - submitting the first step\n";
	my($step_completed, $step_next) = $Pipeline->check_current_step;
	$Pipeline->submit_step($step_next);
}
#$Pipeline->pipe_start() if(defined $OPT{submit});
