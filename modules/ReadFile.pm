package modules::ReadFile;
use base modules::Element;

use strict;
use Data::Dumper;
use modules::Definitions;
use modules::Exception;
use modules::Cohort;
use modules::Individual;

sub new{
	my ($class, $indv) = @_;

	my $self = bless {}, $class;
	$self->{individual} = $indv;
	return $self;
}

sub individual{
	my($self) = shift;
	return $self->{individual};
}#individual

sub readfiles{
	my($self) = shift;
	return $self->{readfiles};
}#readfiles

sub config{
	my($self) = shift;
	return $self->individual->cohort->config;
	#return $self->{config};
}#config

sub pipesteps{
	my($self) = shift;
	return $self->{pipesteps};
}#pipesteps

sub get_readfiles{
	my($self) = @_;
	
	my @read_files;
	
	my $dir_work    = $self->config->read("directories", "work");
	my $dir_reads   = $self->config->read("directories", "reads");
	my $read_regex1 = $self->config->read("global", "read_regex1");
	my $read_regex2 = $self->config->read("global", "read_regex2");

	#warn "Individual ".$self->individual->id."\n";
	#my $dir_indv = join('/', $dir_reads, $self->individual->cohort->id, $self->individual->id);
	my $dir_indv = join('/', $dir_work, $self->individual->cohort->id, $dir_reads, $self->individual->id);
	modules::Exception->throw("Can't access reads directory $dir_indv") if(!-d $dir_indv);
	opendir(DIR, $dir_indv) or modules::Exception->throw("Can't open reads directory $dir_indv");
	while(readdir(DIR)){
		#warn "regx: /$read_regex1/ file: $_\n";
		next if(!/$read_regex1/);
		my $r1 = $_;
		/^(.*)($read_regex2)/;
		my $fp = $1;
		my $rp = $2;
		$rp =~ s/1/2/;
		my $r2 = $r1;
		$r2 =~ s/$read_regex2/$rp/;
		#warn "  read file pair: $r1, $r2\n";
		$r1 = "$dir_indv/$r1";
		$r2 = "$dir_indv/$r2";
		modules::Exception->throw("Can't access reads file R2 '$r2', the mate for R1 file '$r1'") if(!-e $r2);
		push @read_files, [$r1, $r2, $fp];
	}
	closedir(DIR);
	$self->{readfiles} = \@read_files;
	return $self->readfiles;
}#get_readfiles


sub config_add_readfiles{
	my($self) = shift;
	
	$self->config->file_append("[".$self->individual->id."]");
	foreach my $rf(@{$self->readfiles}){
		$self->config->file_append("reads:$rf->[2]=$rf->[0],$rf->[1]")
	}
}#config_add_readfiles

#sub get_pipesteps{
#	my($self) = shift;
#	
#	my %steps = %{$self->config->read("steps")};
#	my @steps_readfile;
#	#sort pipeline steps according to their config key order:
#	foreach my $step(sort{my($aa) = $a=~/^(\d+):\w+/; my($bb) = $b=~/(\d+):\w+/; $aa <=> $bb} keys %steps){
#		next if($step !~/readfile$/);
#		push @steps_readfile, [$step, $steps{$step}];
#	}
#	
#	for(my $i = 0; $i < scalar @steps_readfile; $i++){
#		#warn "$steps_readfile[$i][1]\n";
#		push @{$self->{pipesteps}}, $steps_readfile[$i][1];
#	}
#	return $self->pipesteps;
#}#pipe_steps

sub make_qsub{
	my($self, $step, $config_append) = @_;

	foreach my $rf(@{$self->readfiles}){
		my $qname = $self->individual->cohort->id.'-'.$self->individual->id.'-'.$rf->[2].".$step";
		$self->SUPER::make_qsub(step => $step, qname => $qname, cohort => $self->individual->cohort->id, individual => $self->individual->id, readfile => $rf->[2], config_append => $config_append);
	}
}#make_qsub

return 1;
