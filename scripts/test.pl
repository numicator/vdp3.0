#! /usr/bin/perl -w 
use strict;
use POSIX;
use File::Basename;
use Fcntl ':flock';
use IO::Handle;
use Sys::Hostname;
use modules::Exception;

open(my $fh, ">>", "test.semaphore");
$fh->autoflush(1);

my $r = flock($fh, LOCK_EX + LOCK_NB);
if($r){
	warn "test.semaphore locked all right ($r)\n";
	print $fh POSIX::strftime("%d-%m-%Y_%H:%M:%S", localtime)."\tLOCK_OK\t".(defined $ENV{'PBS_JOBID'}?$ENV{'PBS_JOBID'}: 'NOT_PBS')."\t".hostname()."\n";
}
else{
	warn "test.semaphore failed to lock with '$!' ($r)\n";
	warn join(" ", @!)."\n";
}

while(1){
}

END{
	close $fh;
	warn "DONE test.pl\n"
}