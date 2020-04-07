#! /usr/bin/perl -w 
use strict;
use POSIX;
use File::Basename;
use Fcntl;
use IO::Handle;
use Sys::Hostname;
use modules::Exception;


#use Fcntl qw(SEEK_SET F_WRLCK F_UNLCK F_SETLKW);
#my($pack);
#open(FILE,">test.semaphore");
#$pack = pack('s s l l s', F_WRLCK, SEEK_SET, 0, 1, 0);
#print(fcntl(FILE, F_SETLKW, $pack) . "\n");
#sleep(20);
#$pack = pack('s s l l s', F_UNLCK, SEEK_SET, 0, 1, 0);
#print(fcntl(FILE, F_SETLKW, $pack) . "\n");
#close(FILE);

my $fh;
my $fn = "test.semaphore";
sysopen($fh, $fn, O_CREAT | O_EXCL) or die "failed to open '$fn' in write mode with flock.";

warn "file '$fn' opened in write mode with flock, going into dead loop\n";
while(1){
}

#open(my $fh, ">>", "test.semaphore");
#$fh->autoflush(1);
#
#my $r = flock($fh, LOCK_EX + LOCK_NB);
#if($r){
#	warn "test.semaphore locked all right ($r)\n";
#	print $fh POSIX::strftime("%d-%m-%Y_%H:%M:%S", localtime)."\tLOCK_OK\t".(defined $ENV{'PBS_JOBID'}?$ENV{'PBS_JOBID'}: 'NOT_PBS')."\t".hostname()."\n";
#}
#else{
#	warn "test.semaphore failed to lock with '$!' ($r)\n";
#	warn join(" ", @!)."\n";
#}
#
#while(1){
#}

END{
	close $fh;
	warn "DONE test.pl\n"
}