#! /usr/bin/perl -w 
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Path qw(make_path remove_tree);
use File::Basename;
use Pod::Usage;
use Cwd qw(abs_path);
use modules::Definitions;
use modules::SystemCall;
use modules::Exception;
use modules::Config;
use modules::PED;
use modules::Utils;

use vars qw(%OPT);

my $confdir = modules::Utils::confdir;
modules::Exception->throw("Can't access configuration file '$confdir/pipeline.cnf'") if(!-f "$confdir/pipeline.cnf");
my $Syscall      = modules::SystemCall->new();
my $Config       = modules::Config->new("$confdir/pipeline.cnf");
my $pversion     = $Config->read("global", "version");
my $codebase     = $Config->read("directories", "pipeline");
my $dir_shepherd = $Config->read("directories", "work")."/".$Config->read("pipe_shepherd", "dir");
warn "pipeline version: '$pversion', codebase: '$codebase'\n";
my $user  = $ENV{LOGNAME};
my $jobid = modules::Utils::pbs_jobid;

my $me = abs_path($0);
my $pipe_progress = modules::Utils::scriptdir."/pipe_progress.pl";
my $r;
$r = $Syscall->run($pipe_progress);
if($r){
	warn "\n******************************************************************************************\n";
	warn "*** WARNING: pipe_shepherd failed to run pipe_progress.pl script. It is bad, check it! ***\n";
	warn "******************************************************************************************\n\n";
}

my $BASE     = "pipe_shepherd.$pversion.$user";
my $fname    = "$dir_shepherd/$BASE";
my $cmd = "qstat -f -Fdsv | grep $BASE.qsub | wc -l";
my $njob = `$cmd`;
chomp $njob;
#warn "njob: $njob\n";
if((defined $njob && $njob ne '') && (defined $jobid && $njob > 1 || !defined $jobid && $njob > 0)){
	warn "\n******************************************************************************************\n";
	warn "***   WARNING: another $BASE.qsub has been submitted.\n"; 
	warn "***   This one will not resubmit.\n";
	warn "******************************************************************************************\n\n";
	exit 0;
}

####################################################################################################
# now we reschedule

my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
$hour = $hour < 23? $hour + 1: 0;
my $timenew = sprintf("%02d%02d", $hour, $min);
warn "next runtime for $fname.qsub is: $timenew\n";

make_path($dir_shepherd);
open Q, ">$fname.qsub" or modules::Exception->throw("Can't open $fname.qsub for writing\n");

print Q $Config->read('global', "pbs_shebang")."\n";
print Q "#PBS -P ".$Config->read('global', "pbs_project")."\n";
print Q "#PBS -q ".$Config->read("pipe_shepherd", "pbs_queue")."\n";
print Q "#PBS -a $timenew\n";
print Q "#PBS -l walltime=".$Config->read("pipe_shepherd", "pbs_walltime").",mem=".$Config->read("pipe_shepherd", "pbs_mem").",ncpus=".$Config->read("pipe_shepherd", "pbs_ncpus")."\n";
print Q "#PBS -l storage=".$Config->read('global', "pbs_storage")."\n";
print Q "#PBS -l other=".$Config->read('global', "pbs_other")."\n";
print Q "#PBS -W umask=".$Config->read('global', "pbs_umask")."\n";
print Q "#PBS -o $fname.out\n";
print Q "#PBS -e $fname.err\n\n";
print Q "source $confdir/".$Config->read('global', "env_file")."\n";
print Q "cd $dir_shepherd\n";
print Q "echo \"pwd: \$(pwd)\" >&2\n\n";
print Q "echo \"$me\" >&2\n";
print Q "$me";

close Q;

$cmd = "qsub $fname.qsub";
$r = system($cmd);
if($r){
	modules::Exception->throw("\n******************************************************************************************\n*** WARNING: pipe_shepherd qsub resubmission failed with code $r. It is bad, check it! ***\n******************************************************************************************\n\n");
}
else{
	warn "job re-submission done\n";
	warn "all good till next time\n";
}

END{
	warn "done script ".basename(__FILE__)."\n"
}