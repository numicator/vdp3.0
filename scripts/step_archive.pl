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
my $dir_mdss = $Config->read("directories", "mdss");
warn "pipeline version: '$pversion', codebase: '$codebase'\n";

my $dir_cohort = $Config->read("cohort", "dir");
modules::Exception->throw("Can't access cohort directory $dir_cohort") if(!-d $dir_cohort);
my $dir_reads = $Config->read("directories", "reads");
modules::Exception->throw("Can't access directory $dir_cohort/$dir_reads") if(!-d "$dir_cohort/$dir_reads");
my $dir_qsub = $Config->read("directories", "qsub");
modules::Exception->throw("Can't access directory $dir_cohort/$dir_qsub") if(!-d "$dir_cohort/$dir_qsub");
my $dir_run = $Config->read("directories", "run");
modules::Exception->throw("Can't access directory $dir_cohort/$dir_run") if(!-d "$dir_cohort/$dir_run");
my $dir_result = $Config->read("directories", "result");
modules::Exception->throw("Can't access directory $dir_cohort/$dir_result") if(!-d "$dir_cohort/$dir_result");

my $mdss_project = $Config->read("step:$step", "mdss_project");
my $run_copy = $Config->read("step:$step", "run_copy");

my @cmds;

#prepare dir structure on mdss
push @cmds, "mdss -P $mdss_project rm -rf $dir_mdss/$cohort";
push @cmds, "mdss -P $mdss_project mkdir -p $dir_mdss/$cohort";
push @cmds, "mdss -P $mdss_project mkdir -p $dir_mdss/$cohort/$dir_reads";
push @cmds, "mdss -P $mdss_project mkdir -p $dir_mdss/$cohort/$dir_result";
push @cmds, "mdss -P $mdss_project chmod 770 $dir_mdss/$cohort/*";

#copy files directly located in cohort dir
opendir(DIR, "$dir_cohort") or modules::Exception->throw("Can't open directory $dir_cohort");
while(my $fdir = readdir(DIR)){
	next if($fdir eq '.' || $fdir eq '..');
	next if(! -f "$dir_cohort/$fdir");
	push @cmds, "mdss -P $mdss_project put $dir_cohort/$fdir $dir_mdss/$cohort/";
	push @cmds, "mdss -P $mdss_project chmod 644 $dir_mdss/$cohort/$fdir";
}
closedir(DIR);

#copy read file directory structure
opendir(DIR, "$dir_cohort/$dir_reads") or modules::Exception->throw("Can't open directory $dir_cohort/$dir_reads");
while(my $sdir = readdir(DIR)){
	next if($sdir eq '.' || $sdir eq '..');
	push @cmds, "mdss -P $mdss_project mkdir -p $dir_mdss/$cohort/$dir_reads/$sdir";
	push @cmds, "mdss -P $mdss_project chmod 770 $dir_mdss/$cohort/$dir_reads/$sdir";
	opendir(DIR2, "$dir_cohort/$dir_reads/$sdir") or modules::Exception->throw("Can't open directory $dir_cohort/$dir_reads/$sdir");
	while(my $fdir = readdir(DIR2)){
		next if($fdir eq '.' || $fdir eq '..');
		push @cmds, "mdss -P $mdss_project put $dir_cohort/$dir_reads/$sdir/$fdir $dir_mdss/$cohort/$dir_reads/$sdir/";
	}
	close(DIR2);
	push @cmds, "mdss -P $mdss_project chmod 660 $dir_mdss/$cohort/$dir_reads/$sdir/*";
}
closedir(DIR);

#copy results directory (converting symlinks to files is intetional to ease access)
opendir(DIR, "$dir_cohort/$dir_result") or modules::Exception->throw("Can't open directory $dir_cohort/$dir_result");
while(my $fdir = readdir(DIR)){
	next if($fdir eq '.' || $fdir eq '..');
	push @cmds, "mdss -P $mdss_project put $dir_cohort/$dir_result/$fdir $dir_mdss/$cohort/$dir_result/";
}
closedir(DIR);
push @cmds, "mdss -P $mdss_project chmod 644 $dir_mdss/$cohort/$dir_result/*";

#tar and copy qsub dir
push @cmds, "cd $dir_cohort; tar cvzf qsub.tgz $dir_qsub >&2";
push @cmds, "mdss -P $mdss_project put $dir_cohort/qsub.tgz $dir_mdss/$cohort/";
push @cmds, "mdss -P $mdss_project chmod 660 $dir_mdss/$cohort/qsub.tgz";
push @cmds, "rm $dir_cohort/qsub.tgz";

#tar and copy run dir
if($run_copy){
	push @cmds, "cd $dir_cohort; tar cvzf run.tgz $dir_run >&2";
	push @cmds, "mdss -P $mdss_project put $dir_cohort/run.tgz $dir_mdss/$cohort/";
	push @cmds, "mdss -P $mdss_project chmod 660 $dir_mdss/$cohort/run.tgz";
	push @cmds, "rm $dir_cohort/run.tgz";
}
else{
	warn "the cohort run directory will not be archived.\n";
}

#execute commands
my $r;
foreach my $cmd(@cmds){
	#warn "$cmd\n";
	$r = $Syscall->run($cmd);
	exit(1) if($r);
}

exit(0);

END{
	warn "done script ".basename(__FILE__)."\n"
}
