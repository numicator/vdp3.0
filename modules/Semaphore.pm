package modules::Semaphore;

use strict;
use POSIX;
use File::Basename;
use Fcntl;
use IO::Handle;
use Sys::Hostname;
use modules::Definitions;
use modules::Exception;
use modules::Utils;

sub new{
	my ($class, $file_name) = @_;

	my $self = bless {}, $class;
	$self->{file_name} = $file_name . $self->file_suffix;
	return $self;
}

sub DESTROY
{  
	my($self) = shift;
	close $self->fh if($self->fh);
}#DESTROY

sub locked{
	my($self) = shift;
	return $self->{locked}
}#locked

sub fh{
	my($self) = shift;
	return $self->{fh}
}#fh

sub file_suffix{
	my($self) = shift;
	return '.lock'
}#file_suffix

sub file_name{
	my($self) = shift;
	return $self->{file_name}
}#file_name

sub lock{
	my($self, $waitforit) = @_;
	my $ret = 0;
	
	my $ok;
	my $fh;
	warn "will be waiting...\n" if($waitforit);
	print STDERR "waiting to lock lockfile ".basename($self->{file_name})."...";
	for(;;){
		$ok = sysopen(FH, $self->{file_name}, O_CREAT | O_EXCL | O_WRONLY);
		if(!$ok){
			if(open(F, $self->{file_name})){
				my $modtime = (stat(F))[9];
				my $age = time - $modtime;
				print STDERR " lock file age: $age"."s (max allowed age is ".LOCK_MAX_AGE."s)," if(!defined $waitforit);
				if($age > LOCK_MAX_AGE){
					print STDERR " lock file considered stale, overriding and retrying,";
					close F;
					unlink($self->{file_name});
					next;
				}
				close F;
			}
		}
		if(!$ok && defined $waitforit){
			sleep(1);
			print STDERR ".";
			next
		}
		else{
			last
		}
	}

	$ret = $ok? 1: 0;
	
	if($ok){
		warn " locked\n";	}
	else{
		warn " failed to lock\n";
		return $ret;
	}
	
	$fh = (*FH);
	$fh->autoflush(1);
	$self->{fh} = $fh;
	$self->{locked} = $ret;
	print FH "".modules::Utils::get_time_stamp."\tLOCK\t".(defined modules::Utils::pbs_jobid()? modules::Utils::pbs_jobid(): 'NOT_PBS')."\t".modules::Utils::hostname()."\t".modules::Utils::username."\n";

	return $ret;
}#lock

sub unlock{
	my($self, $force) = @_;
	my $ret = 1;
	
	return if(!$self->{locked} && !$force);
	
	if($self->fh){
		close $self->fh;
		unlink $self->file_name;
		warn "lock file ".basename($self->file_name)." released\n";
	}
	else{
		warn "attempt to release non-existing lock file\n";
	}
	return $ret;
}#unlock

return 1