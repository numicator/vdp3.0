package  modules::SystemCall;
use strict;

use modules::Exception;

sub new{
	my ($class) = @_;
	my $self = bless {}, $class;
	return $self;
}

sub run{
	my($self, $command, $bail) = @_;

	my $ret;
	$command = "set -o pipefail; $command";
	warn "modules::SystemCall::run: $command\n";
	if($ret = system($command))
	{
		if(defined $bail && $bail){
			warn "command exited with non-zero status $ret (bailing out)\n";
		}
		else{
			#warn "command exited with non-zero status $ret (dying)\n";
			modules::Exception->throw("command exited with non-zero status $ret (dying)")
		}
	} 
	return $ret;
}#run

return 1;
