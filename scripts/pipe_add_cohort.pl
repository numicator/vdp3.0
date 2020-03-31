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

my $pversion    = $Config->read("global", "version");
my $codebase    = $Config->read("directories", "pipeline");
my $dir_reads   = $Config->read("directories", "reads");
my $dir_cohorts = $Config->read("directories", "work");
warn "pipeline version: '$pversion', codebase: '$codebase'\n";

modules::Exception->throw("Expected either argument 'cohort' xor 'data_file'") if(defined $OPT{cohort} && defined $OPT{data_file} || !defined $OPT{cohort} && !defined $OPT{data_file});
#modules::Exception->throw("Missing mandatory argument 'cohort'") if(!defined $OPT{cohort});

if(defined $OPT{data_file}){
	modules::Exception->throw("Specify argumant 'project'") if(!defined $OPT{project});
	my $project = $OPT{project};
	my $Vardb = modules::Vardb->new($Config);
	$Vardb->get_data_tsv($OPT{data_file}, $OPT{dir_fastq});
	#foreach my $smpl(keys %{$Vardb->samples}){warn "$smpl\n"}
	$Vardb->request_family_trees;

	my $dbfile = "$dir_cohorts/$pversion.db";
	my $Semaphore = modules::Semaphore->new($dbfile);
	if(!$Semaphore->lock(0)){
		warn "couldn't apply lock to semaphore file '".$Semaphore->file_name."'; exiting\n";
		die;
	}

	my $id = 0;
	open F, $dbfile or modules::Exception->throw("Couldn't access database file '$dbfile'");
	while(<F>){
		chomp;
		next if(!/^$project\_cohort(\d+)/);
		$id = $1 if($id < $1);
	}
	close F;
	$id++;
	warn "next cohort number for project $project is $id\n";
	my $O;
	open $O, ">>$dbfile" or modules::Exception->throw("Couldn't access database file '$dbfile' for writing");
	$O->autoflush(1);
	foreach my $famid(keys %{$Vardb->cohorts}){
		my $cohort = sprintf("%s_cohort%04d", $project, $id);
		warn "creting cohort $cohort ($famid)\n";
		print $O "$cohort\tSTART\t".modules::Utils::get_time_stamp."\t".join(',', sort keys %{$Vardb->cohorts->{$famid}})."\n";
		my $pedex = $Vardb->pedx($famid, $cohort, $Vardb->dir_ped."/$cohort.pedx");
		#foreach(@$pedex){warn join("\t", @$_)."\n";}warn "\n";
		$id++;
	}
	close $O;
	$Semaphore->unlock;
	die "greaceful death\n";
}

if(defined $OPT{cohort}){
	my $cohort = $OPT{cohort};
	$dir_reads .= "/$cohort";
	modules::Exception->throw("Can't access reads directory $dir_reads") if(!-d $dir_reads);
	#warn "cohort read directory: $dir_reads\n";

	my $PED = modules::PED->new("$dir_reads/$cohort.pedx");
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
}