package modules::Individual;
use base modules::Element;

use strict;
use Data::Dumper;
use modules::Definitions;
use modules::Exception;
use modules::ReadFile;

sub new{
	my ($class, $id, $cohort) = @_;

	my $self = bless {}, $class;
	$self->{id} = $id;
	$self->{cohort} = $cohort;
	return $self;
}

sub id{
	my($self) = shift;
	return $self->{id};
}#id

sub cohort{
	my($self) = shift;
	return $self->{cohort};
}#cohort

sub readfiles{
	my($self) = shift;
	return $self->{readfiles};
}#readfiles

sub config{
	my($self) = shift;
	return $self->cohort->config;
}#config

sub pipesteps{
	my($self) = shift;
	return $self->{pipesteps};
}#pipesteps

sub get_readfiles{
	my($self) = shift;
	$self->{readfiles} = modules::ReadFile->new($self);
	$self->{readfiles}->get_readfiles();
}#get_readfiles

sub config_add_readfiles{
	my($self) = shift;
	
	$self->readfiles->config_add_readfiles;
}#config_add_readfiles

#sub get_pipesteps{
#	my($self) = shift;
#	
#	$self->{readfiles}->get_pipesteps();
#
#	my %steps = %{$self->config->read("steps")};
#	my @steps_individual;
#	#sort pipeline steps according to their config key order:
#	foreach my $step(sort{my($aa) = $a=~/^(\d+):\w+/; my($bb) = $b=~/(\d+):\w+/; $aa <=> $bb} keys %steps){
#		next if($step !~/individual$/);
#		push @steps_individual, [$step, $steps{$step}];
#	}
#	
#	for(my $i = 0; $i < scalar @steps_individual; $i++){
#		#warn "$steps_individual[$i][1]\n";
#		push @{$self->{pipesteps}}, $steps_individual[$i][1];
#	}
#	return $self->pipesteps;
#}#get_pipesteps

sub make_qsub{
	my($self, $step, $config_append) = @_;

	my $qname = $self->cohort->id.'-'.$self->id.".$step";
	#$self->SUPER::make_qsub($step, $qname);
	$self->SUPER::make_qsub(step => $step, qname => $qname, cohort => $self->cohort->id, individual => $self->id, config_append => $config_append);
}#make_qsub

return 1;
