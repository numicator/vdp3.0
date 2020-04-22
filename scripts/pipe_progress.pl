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
	   		"step=s",
	   		"split=s",
	   		"status=s",
	   		"no_submit"
	   		);
	   		
pod2usage(-verbose => 2) if $OPT{man};
pod2usage(1) if ($OPT{help});

	   
=pod

=head1 SYNOPSIS

pipe_progress.pl

Required flags: NONE

=head1 OPTIONS

    -help  brief help message
    -man   full documentation

=head1 NAME

pipe_progress.pl -> Does something useful

=head1 DESCRIPTION

Fab 2020

a script that ...

=head1 AUTHOR

Marcin Adamski

=head1 EXAMPLE

./pipe_progress.pl

=cut

my $confdir = modules::Utils::confdir;
modules::Exception->throw("Can't access configuration file '$confdir/pipeline.cnf'") if(!-f "$confdir/pipeline.cnf");
my $Config   = modules::Config->new("$confdir/pipeline.cnf");
my $Syscall  = modules::SystemCall->new();

my $pversion    = $Config->read("global", "version");
my $codebase    = $Config->read("directories", "pipeline");
my $dir_cohorts = $Config->read("directories", "work");
warn "pipeline version: '$pversion', codebase: '$codebase'\n";

my $user_current = modules::Utils::username;

my @cohorts;
if(!defined $OPT{cohort}){
	push @cohorts, modules::Utils::get_cohorts($dir_cohorts, 'in_progress');
	undef $OPT{step};
	undef $OPT{split};
	undef $OPT{status};
}
else{
	push @cohorts, $OPT{cohort};
}

my $Pipeline = modules::Pipeline->new(config => $Config);
$Pipeline->get_qjobs;

foreach my $cohort(@cohorts){
	my $dir_cohort .= "$dir_cohorts/$cohort";
	warn "\nprogressing cohort '$cohort'\n";

	modules::Exception->throw("Can't access cohort directory $dir_cohort") if(!-d $dir_cohort);
	#warn "cohort read directory: $dir_cohort\n";
	my $Config = modules::Config->new("$dir_cohort/pipeline.cnf");
	modules::Exception->throw("Cohort directory '$dir_cohort' is not the same as '".$Config->read("cohort", "dir")."' in $dir_cohort/pipeline.cnf, section '[cohort]', value 'dir'") if($Config->read("cohort", "dir") !~ /$dir_cohort\/?/);
	
	my $username = $Config->read("cohort", "username");
	if($user_current ne $username){
		warn "cohort '$cohort' belongs to user '$username', not me '$user_current', skipping\n";
		next;
	}
	
	my $smp_name = basename(__FILE__);
	$smp_name =~ s/\.pl$//;
	$smp_name = "$dir_cohort/$smp_name";
	
	my $Semaphore = modules::Semaphore->new($smp_name);
	$smp_name = $Semaphore->file_name;
	if(! $Semaphore->lock){
		warn "couldn't apply lock to semaphore file '".basename($smp_name)."' meaning another ".basename(__FILE__)." is curently running on cohort $cohort; backing off\n";
		next;
	}
	my $PED = modules::PED->new("$dir_cohort/$cohort.pedx");
	modules::Exception->throw("cohort PED file must contain exactly one family") if(scalar keys %{$PED->ped} != 1);
	modules::Exception->throw("cohort id submited as argument is not the same as cohort id in PED: '$cohort' ne '".(keys %{$PED->ped})[0]."'") if((keys %{$PED->ped})[0] ne $cohort);

	my $Cohort = modules::Cohort->new("$cohort", $Config, $PED);
	if($Cohort->has_completed){
		warn "cohort '$cohort' has already completed the pipeline\n";
	}
	elsif($Cohort->has_notready_fastq){
		warn "cohort '$cohort' has not yet completed copying of the fastq files\n";
	}
	else{
		$Cohort->add_individuals_ped();
		$Pipeline->set_cohort(cohort => $Cohort);
		$Pipeline->get_pipesteps;
		#$Pipeline->get_qjobs;
		warn "running Pipeline->check_current_step('".(defined $OPT{step}? $OPT{step}: '')."')\n";
		my($step_completed, $step_next) = $Pipeline->check_current_step($OPT{step});
		if(defined $OPT{no_submit}){
			warn "no job submissions by user's request\n";
		}
		else{
			$Pipeline->submit_step($step_next) if(defined $step_next);
		}
	}#if($Cohort->has_completed)
	$Semaphore->unlock;
}#foreach(@cohorts)


END{
	warn "\ndone script ".basename(__FILE__)."\n"
}


=cut
for f in $(ls -tr TEST1/qsub/*.status); do echo "=== $f ===>"; cat $f; echo; done
for f in $(ls -tr TEST1/qsub/*.err); do echo "=== $f ===>"; cat $f; echo; echo; done