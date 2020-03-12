package modules::Cohort;
use base modules::Element;

use strict;
use File::Path qw(make_path remove_tree);
use File::Basename;
use File::Copy qw(cp);
use modules::Definitions;
use modules::Exception;
use modules::Individual;
use Data::Dumper;

sub new{
	my($class, $id, $config, $ped) = @_;
	my $self = bless {}, $class;
	$self->{id}     = $id;
	$self->{config} = $config;
	$self->{ped}    = $ped;
	return $self;
}

sub id{
	my($self) = shift;
	return $self->{id};
}#id

sub ped{
	my($self) = shift;
	return $self->{ped};
}#ped

sub individual{
	my($self) = shift;
	return $self->{individual};
}#individual

sub config{
	my($self) = shift;
	return $self->{config};
}#config

sub pipesteps{
	my($self) = shift;
	return $self->{pipesteps};
}#pipesteps

sub make_workdir{
	my($self, $overwrite) = @_;
	
	my $cohort     = $self->id;
	my $config     = $self->config;
	my $dir_work   = $config->read("directories", "work");
	my $dir_qsub   = $config->read("directories", "qsub");
	my $dir_run    = $config->read("directories", "run");
	my $dir_tmp    = $config->read("directories", "tmp");
	my $dir_result = $config->read("directories", "result");

	if(-d "$dir_work/$cohort"){
		if($overwrite){
			warn "removing existing working directory '$dir_work/$cohort'\n";
			remove_tree("$dir_work/$cohort");
		}
		else{
			warn "working directory '$dir_work/$cohort' already exists; it will NOT be re-created\n";
		}
	}
	#if(-d "$dir_work/$cohort"){
	#	modules::Exception->throw("working directory '$dir_work/$cohort' already exists, use -overwrite to proceed") if(!$overwrite);
	#	warn "removing existing working directory '$dir_work/$cohort'\n";
	#	remove_tree("$dir_work/$cohort");
	#}
	make_path("$dir_work/$cohort/$dir_qsub");
	make_path("$dir_work/$cohort/$dir_run");
	make_path("$dir_work/$cohort/$dir_run/$dir_tmp");
	make_path("$dir_work/$cohort/$dir_result");
	#copy config file
	my($cfn, $cdir) = fileparse($config->file_name);
	cp($config->file_name, "$dir_work/$cohort/$cfn") or modules::Exception->throw($!);
	$config->reload("$dir_work/$cohort/$cfn");
	$self->config->file_append("\n#".('*'x20)." Cohort $cohort configuration ".('*'x20));
	$self->config->file_append("[cohort]");
	$self->config->file_append("id=$cohort\ndir=$dir_work/$cohort");
	$config->reload("$dir_work/$cohort/$cfn");
	#copy PED file
	($cfn, $cdir) = fileparse($self->ped->file_name);
	cp($self->ped->file_name, "$dir_work/$cohort/$cfn") or modules::Exception->throw($!);
	$self->ped->reload("$dir_work/$cohort/$cfn");
}#make_workdir

sub load_ped{
	my($self, $ped) = @_;
	$self->{ped} = $ped;	
}#load_ped

sub add_individual{
	my($self, $id) = @_;
	my $i = modules::Individual->new($id, $self);
	push @{$self->{individual}}, $i;
	$i->get_readfiles();
}#add_individual

sub config_add_readfiles{
	my($self) = shift;
	
	$self->config->file_append("\n#".('*'x20)." fastq read files ".('*'x20));
	foreach my $indv(@{$self->individual}){
		$indv->config_add_readfiles;
	}
	$self->config->reload();
}#config_add_readfiles

sub add_individuals_ped{
	my($self, $overwrite) = @_;
	
	foreach my $indv(keys %{$self->ped->ped->{$self->id}}){
		#warn "$indv\n";
		$self->add_individual($indv);
		#$self->ped->ped->{$self->id}{$indv}{capturekit}
		#$self->config->file_append("id=$cohort\ndir=$dir_work/$cohort");
	}
}#add_individuals_ped

#sub get_pipesteps{
#	my($self) = shift;
#
#	my %steps = %{$self->config->read("steps")};
#	my @steps_sort;
#	#sort pipeline steps according to their config key order:
#	foreach my $step(sort{my($aa) = $a=~/^(\d+):\w+/; my($bb) = $b=~/(\d+):\w+/; $aa <=> $bb} keys %steps){
#		warn "  $step\n";
#		push @{$self->{pipesteps}}, [$step, $steps{$step}];
#	}
#	return $self->pipesteps;
#}#get_pipesteps

sub make_qsub{
	my($self, $step, $config_append) = @_;

	my $qname = $self->id.".$step";
	#$self->SUPER::make_qsub($step, $qname);
	$self->SUPER::make_qsub(step => $step, qname => $qname, cohort => $self->id, config_append => $config_append);
}#make_qsub

1
