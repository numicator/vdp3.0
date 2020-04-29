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
	   		"published"
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

pipe_get_to_publish.pl -> Does something useful

=head1 DESCRIPTION

April 2020

a script that ...

=head1 AUTHOR

Marcin Adamski

=head1 EXAMPLE

./pipe_get_to_publish.pl

=cut

my $confdir = modules::Utils::confdir;
modules::Exception->throw("Can't access configuration file '$confdir/pipeline.cnf'") if(!-f "$confdir/pipeline.cnf");
my $Config   = modules::Config->new("$confdir/pipeline.cnf");
my $Syscall  = modules::SystemCall->new();

my $pversion    = $Config->read("global", "version");
my $codebase    = $Config->read("directories", "pipeline");
my $dir_cohorts = $Config->read("directories", "work");
warn "pipeline version: '$pversion', codebase: '$codebase'\n";

my $Pipeline = modules::Pipeline->new(config => $Config);

$Pipeline->database_lock;

if(defined $OPT{published}){
	warn "ids of cohorts already published\n";
	foreach(@{$Pipeline->database_cohort_by_status(COHORT_RUN_PUBLISHED)}){
		print join("\t", @$_)."\n"
	}
}
else{
	warn "ids of cohorts to publish\n";
	my $done = $Pipeline->database_cohort_by_status(COHORT_RUN_DONE_PUBLIC);
	my %published;
	foreach(@{$Pipeline->database_cohort_by_status(COHORT_RUN_PUBLISHED)}){
		$published{$_->[0]} = 1;
	}
	foreach(@$done){
		print join("\t", @$_)."\n" if(!$published{$_->[0]});
	}
}

END{
	$Pipeline->database_unlock;
	warn "done script ".basename(__FILE__)."\n"
}
