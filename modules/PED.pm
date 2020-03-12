package modules::PED;

use strict;
use modules::Exception;
use Data::Dumper;

sub new {
	my ($class, $file_name) = @_;
	my $self = bless {}, $class;
	$self->reload($file_name);
	return $self;
}#new


sub file_name{
	my $self = shift;
	return $self->{file_name};
}#file_name

sub reload(){
	my ($self, $file_name) = @_;
	
	$self->{file_name} = $file_name if(defined $file_name);
	#warn("loading configuration file '".$self->file_name."'\n");
	$self->{ped} = $self->_load();
	$self->{txt} = '';
}#reload

#Parse a ped file
sub _load{
	my($self) = shift;

	open F, $self->{file_name} or  modules::Exception->throw("PED file '$self->{file_name}' can't be accessed.'");

  my %ped_data;

	while(<F>){
		$self->{txt} .= $_;
		chomp;
		next if(/^\s*$/ || /^#/);
		my @fields = split "\t";
		modules::Exception->throw("PED: Expecting Ped file with at least six fields (family_id, id, father, mother, sex, and affected") if(@fields < 6);
		#Cohort_ID	Individual_ID	Paternal_ID	Maternal_ID	Sex	Phenotype	Kit	APFdb_ID	APFrequest_ID
		my($family, $id, $father, $mother, $sex, $affected, $kit, $dbid, $reqid) = @fields;
		modules::Exception->throw("PED: Affected status must be 1 or 2, not '$affected'\n$_\n") if($affected !~ /[12]/);
		modules::Exception->throw("PED: Sex must be 1 or 2") if($sex !~ /[12]/);

		$ped_data{$family}{$id}{father}    = $father;
		$ped_data{$family}{$id}{mother}    = $mother;
		$ped_data{$family}{$id}{phenotype} = $affected;
		$ped_data{$family}{$id}{sex}       = $sex;
		#the 'extra' fields:
		$ped_data{$family}{$id}{capturekit}   = $kit;
		$ped_data{$family}{$id}{apfdbid}      = $dbid;
		$ped_data{$family}{$id}{apfrequestid} = $reqid;
	}
	close F;
	return \%ped_data;
}#_load

#Get ped data from a file
sub ped{
	my($self) = shift;
	return $self->{ped};
}#ped

sub txt{
	my($self) = shift;
	return $self->{txt};
}#txt

sub dump{
	my($self) = shift;
	print Dumper($self->{ped});
}#dump


1;