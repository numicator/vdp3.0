package modules::Semaphore;

use strict;
use POSIX;
use File::Basename;
use Fcntl ':flock';
use IO::Handle;
use Sys::Hostname;
use modules::Exception;
use modules::Utils;

sub new{
	my ($class, $file_name) = @_;

	my $self = bless {}, $class;
	$self->{file_name} = $file_name . $self->file_suffix;
	open($self->{file_handle}, ">>", $self->file_name) or modules::Exception->throw("Can't open semaphore file '".$self->file_name."' for writing");
	$self->fh->autoflush(1);
	return $self;
}

sub DESTROY
{  
	my($self) = shift;
	close $self->fh;
}#DESTROY

sub locked{
	my($self) = shift;
	return $self->{locked}
}#locked

sub fh{
	my($self) = shift;
	return $self->file_handle
}#fh

sub file_suffix{
	my($self) = shift;
	return '.semaphore'
}#file_suffix

sub file_handle{
	my($self) = shift;
	return $self->{file_handle}
}#file_handle

sub file_name{
	my($self) = shift;
	return $self->{file_name}
}#file_name

sub lock{
	my($self, $non_blocking) = shift;
	my $ret = 0;
	
	$non_blocking = !defined $non_blocking || $non_blocking != 0? LOCK_NB: 0;
	
	if(flock($self->fh, LOCK_EX | LOCK_NB)){
		warn basename($self->file_name)." locked all right\n";
		#print $fh POSIX::strftime("%d-%m-%Y_%H:%M:%S", localtime)."\tLOCK\t".(defined $ENV{'PBS_JOBID'}?$ENV{'PBS_JOBID'}: 'NOT_PBS')."\t".hostname()."\n";
		my $fh = $self->fh;
		print $fh "".modules::Utils::get_time_stamp."\tLOCK\t".(defined modules::Utils::pbs_jobid()? modules::Utils::pbs_jobid(): 'NOT_PBS')."\t".modules::Utils::hostname()."\n";
		$ret = 1;
	}
	else{
		warn $self->file_name." failed to lock with '$!'\n";
	}
	$self->{locked} = $ret;
	return $ret;
}#lock

sub unlock{
	my($self, $force) = @_;
	my $ret = 0;
	
	return if(!$self->{locked} && !$force);
	
	if(flock($self->fh, LOCK_UN)){
		warn basename($self->file_name)." unlocked all right\n";
		my $fh = $self->fh;
		print $fh "".modules::Utils::get_time_stamp()."\tUNLOCK\t".(defined modules::Utils::pbs_jobid()? modules::Utils::pbs_jobid(): 'NOT_PBS')."\t".modules::Utils::hostname()."\n";
		$self->{locked} = 0;
		$ret = 1;
	}
	else{
		warn $self->file_name." failed to unlock with '$!'\n";
	}
	return $ret;
}#unlock

return 1