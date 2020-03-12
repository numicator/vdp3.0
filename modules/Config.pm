package modules::Config;

use strict;
use modules::Exception;
use Data::Dumper;

sub new{
	my ($class, $file_name) = @_;
	my $self = bless {}, $class;
	$self->reload($file_name);
	return $self;
}

sub reload(){
	my ($self, $file_name) = @_;
	
	$self->{file_name} = $file_name if(defined $file_name);
	#warn("loading configuration file '".$self->file_name."'\n");
	($self->{cnf}, $self->{ordinal}) = $self->_load();
	$self->{txt} = '';
}#reload

sub _load{
	my($self) = shift;
	
	my %cnf;
	my %ordinal;
	
	#warn("loading file: $self->{file_name}\n");
	open F, $self->{file_name} or  modules::Exception->throw("Configuration file '$self->{file_name}' can't be accessed.'");
	my $sect;
	my $asarray;
	my $inx;
	while(<F>)
	{
		$self->{txt} .= $_;
		chomp;
		next if(/^\s*$/ || /^#/);
		if(/^\s*<asarray>\s*$/){
			$asarray = 1;
			next;
		}
		#warn("$_\n");		
		if(/^\[([\w:]+)\]/){	#section header
			$sect    = $1;
			$asarray = 0;
			$inx = 0;
		}
		else{
			modules::Exception->throw("Configuration file '$self->{file_name}' has entry without any section") if(!defined $sect);
			modules::Exception->throw("Configuration file '$self->{file_name}' unexpected line format at line '$.'") if(!/^\s*([\w:]+)\s*=\s*(.+)/);
			if($asarray){
				push @{$cnf{$sect}{$1}}, $2;
				push @{$ordinal{$sect}{$1}}, $inx++;
			}
			else{		
				modules::Exception->warning("Configuration file '$self->{file_name}' section '$sect' redefinition of '$1' ($cnf{$sect}{$1}) at line $.") if(defined $cnf{$sect}{$1});
				$cnf{$sect}{$1} = $2;
				$ordinal{$sect}{$1} = $inx++;
			}
		}
	}
	close F;
	return (\%cnf, \%ordinal);
}#_load

sub _config{
	my $self = shift;
	return $self->{cnf};
}#_config

sub _ordinal{
	my $self = shift;
	return $self->{ordinal};
}#_ordinal

sub file_name{
	my $self = shift;
	return $self->{file_name};
}#file_name

sub read{
	my($self, $section, $key) = @_;
	my $cnf     = $self->_config;

	modules::Exception->throw("Configuration section '$section' not defined") if(!defined $cnf->{$section});
	my($v, $o);
	if(defined $key){
		modules::Exception->throw("Configuration key '$key' in section '$section' not defined") if(!defined $cnf->{$section}{$key});
		$v = $cnf->{$section}{$key};
		while($v =~ /(?<!\\)\$\[?(\w+)/){
			my $s = 'global';
			my $k = $1;
			if($v =~ /(?<!\\)\$\[([\w:]+)\](\w+)/){
				$s = $1;
				$k = $2;
				modules::Exception->throw("Var. Configuration section '$s' not defined") if(!defined $cnf->{$s});
				modules::Exception->throw("Var. Configuration key '$k' in section '$s' not defined") if(!defined $cnf->{$s}{$k});
				$v =~ s/(?<!\\)\$\[$s\]$k/$cnf->{$s}{$k}/;
			}
			else{
				modules::Exception->throw("Var. Configuration section '$s' not defined") if(!defined $cnf->{$s});
				modules::Exception->throw("Var. Configuration key '$k' in section '$s' not defined") if(!defined $cnf->{$s}{$k});
				$v =~ s/(?<!\\)\$(\w+)/$cnf->{$s}{$k}/;
			}
		}
	}#if(defined $key)
	else{
		$v = $cnf->{$section};
	}
	$v =~ s/\\(?=\$)//g;
	return $v;
}#read

sub ordinal{
	my($self, $section, $key) = @_;
	my $ordinal = $self->_ordinal;

	modules::Exception->throw("Configuration section '$section' not defined") if(!defined $ordinal->{$section});
	my $o;
	if(defined $key){
		modules::Exception->throw("Configuration key '$key' in section '$section' not defined") if(!defined $ordinal->{$section}{$key});
		$o = $ordinal->{$section}{$key};
	}#if(defined $key)
	return $o;
}#ordinal

sub txt{
	my($self) = shift;
	return $self->{txt};
}#txt

sub dump{
	my($self) = shift;
	print Dumper($self->_config);
}#dump

sub file_append{
	my($self, $txt) = @_;
	open F, ">>".$self->file_name or modules::Exception->throw("Can't open ".$self->file_name." for writing\n");
	chomp $txt;
	#warn "appending to config file ".$self->file_name." $txt\n";
	print F "$txt\n";
	close F;
}

return 1;
