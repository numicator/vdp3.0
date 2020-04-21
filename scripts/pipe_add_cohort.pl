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
use modules::Vardb;
use modules::Utils;
use modules::Semaphore;

use vars qw(%OPT);


GetOptions(\%OPT, 
	   		"help|h",
	   		"man|m",
	   		"project=s",
	   		"cohort=s",
	   		"data_file=s",
	   		"dir_fastq=s",
	   		"overwrite",
	   		"delete",
	   		"submit",
	   		"qsub_copy",
	   		"dryrun"
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
my $confdir = modules::Utils::confdir;
modules::Exception->throw("Can't access configuration file '$confdir/pipeline.cnf'") if(!-f "$confdir/pipeline.cnf");
my $Config   = modules::Config->new("$confdir/pipeline.cnf");
my $Syscall  = modules::SystemCall->new();

my $pversion    = $Config->read("global", "version");
my $codebase    = $Config->read("directories", "pipeline");
my $dir_reads   = $Config->read("directories", "reads");
my $dir_cohorts = $Config->read("directories", "work");
warn "pipeline version: '$pversion', codebase: '$codebase'\n";

modules::Exception->throw("Expected either argument 'cohort' xor 'data_file'") if(defined $OPT{cohort} && defined $OPT{data_file} || !defined $OPT{cohort} && !defined $OPT{data_file});
modules::Exception->throw("Argument 'delete' must be used with argument 'cohort'") if(!defined $OPT{cohort} && defined $OPT{'delete'});

my $Pipeline = modules::Pipeline->new(config => $Config);
$Pipeline->database_lock;

if(defined $OPT{data_file}){
	modules::Exception->throw("Specify argumant 'project'") if(!defined $OPT{project});
	my $project = $OPT{project};
	my $Vardb = modules::Vardb->new($Config);
	$Vardb->get_data_tsv($OPT{data_file}, $OPT{dir_fastq});
	#foreach my $smpl(keys %{$Vardb->samples}){warn "$smpl\n"}
	$Vardb->request_family_trees;

	my $id = $Pipeline->database_lastcohort($project);
	modules::Exception->throw("couldn't read from database the last cohort number for project $project") if(!defined $id);
	$id++;
	warn "next available cohort number for project $project is $id\n";
	foreach my $famid(keys %{$Vardb->cohorts}){
		my $cohort = sprintf("%s_cohort%04d", $project, $id);
		warn "creting cohort $cohort ($famid)\n";
		#print $O "$cohort\tSTART\t".modules::Utils::get_time_stamp."\t".join(',', sort keys %{$Vardb->cohorts->{$famid}})."\n";
		my $pedex = $Vardb->pedx($famid, $cohort, $Vardb->dir_ped."/$cohort.pedx");
		#foreach(@$pedex){warn join("\t", @$_)."\n";}warn "\n";
		my $PED = modules::PED->new($Vardb->dir_ped."/$cohort.pedx");
		modules::Exception->throw("cohort PED file must contain exactly one family") if(scalar keys %{$PED->ped} != 1);
		modules::Exception->throw("cohort id submited as argument is not the same as cohort id in PED: '$cohort' ne '".(keys %{$PED->ped})[0]."'") if((keys %{$PED->ped})[0] ne $cohort);
		warn "processing cohort $cohort\n";

		$Config = modules::Config->new("$confdir/pipeline.cnf"); #we need to refresh our config for each cohort
		my %fqfiles;
		foreach(sort keys %{$Vardb->cohorts->{$famid}}){
			#$Vardb->samples->{$_}->{$fq};
			$fqfiles{$_} = $Vardb->samples->{$_}->{fq};
		}
		if(defined $OPT{dryrun}){
			warn "*** dryrun - no actuall actions to be performed ***\n";
		}
		else{
			my $Cohort = modules::Cohort->new("$cohort", $Config, $PED, \%fqfiles);
			$Pipeline->set_cohort(cohort => $Cohort);
			$Pipeline->database_record(COHORT_RUN_START, join(',', sort keys %{$Vardb->cohorts->{$famid}})."\t".modules::Utils::username);
			$Cohort->make_workdir($OPT{overwrite}, $OPT{qsub_copy});
			if(!defined $OPT{qsub_copy}){
				$Cohort->add_individuals_ped;
				$Cohort->config_add_readfiles;
				$Pipeline->get_pipesteps;
				$Pipeline->make_qsubs(1);
				$Pipeline->config->reload;
			
				if(defined $OPT{submit}){
					warn "starting the pipeline - submitting the first step\n";
					my($step_completed, $step_next) = $Pipeline->check_current_step;
					$Pipeline->submit_step($step_next);
				}
			}#if(!defined $OPT{qsub_copy})
		}#else if(defined $OPT{dryrun})
		$id++;
	}#foreach my $famid(keys %{$Vardb->cohorts})
	#die "greaceful death\n";
}

if(defined $OPT{cohort}){
	my $cohort = $OPT{cohort};
	my $dir_cohort .= "$dir_cohorts/$cohort";
	
	if(defined $OPT{delete}){
		warn "deleting directory $dir_cohorts/$cohort\n";
		remove_tree($dir_cohort);
		$Pipeline->database_unlock;
		exit 0;
	}
	
	#$Config = modules::Config->new("$dir_cohort/pipeline.cnf");
	my $PED = modules::PED->new("$dir_cohort/$cohort.pedx");
	modules::Exception->throw("cohort PED file must contain exactly one family") if(scalar keys %{$PED->ped} != 1);
	modules::Exception->throw("cohort id submited as argument is not the same as cohort id in PED: '$cohort' ne '".(keys %{$PED->ped})[0]."'") if((keys %{$PED->ped})[0] ne $cohort);
	warn "processing cohort '$cohort'\n";
	my $Cohort = modules::Cohort->new("$cohort", $Config, $PED);
	$Pipeline->set_cohort(cohort => $Cohort);
	$Cohort->reset_completed if($Cohort->has_completed);
	$Cohort->make_workdir($OPT{overwrite});
	$Cohort->add_individuals_ped;
	$Cohort->config_add_readfiles;

	my @individuals;
	foreach(@{$Cohort->individual}){
		push @individuals, $_->id;
	}
	$Pipeline->database_record(COHORT_RUN_START, join(',', sort @individuals)."\t".modules::Utils::username);
	$Pipeline->get_pipesteps;
	$Pipeline->make_qsubs(1);
	$Pipeline->config->reload;

	if(defined $OPT{submit}){
		warn "starting the pipeline - submitting the first step\n";
		my($step_completed, $step_next) = $Pipeline->check_current_step;
		$Pipeline->submit_step($step_next);
	}
	#$Pipeline->pipe_start() if(defined $OPT{submit});
}

END{
	$Pipeline->database_unlock if(defined $Pipeline);
	warn "done script ".basename(__FILE__)."\n"
}

exit 0;