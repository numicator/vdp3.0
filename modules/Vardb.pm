package modules::Vardb;

use strict;
use File::Path qw(make_path remove_tree);
use File::Basename;
use File::Copy qw(cp);
use Cwd qw(abs_path);
use File::Spec;
use modules::Definitions;
use modules::Exception;
use Data::Dumper;

sub new{
	my($class, $config) = @_;
	my $self = bless {}, $class;
	$self->{config} = $config;
	return $self;
}

sub config{
	my($self) = shift;
	return $self->{config};
}#config

sub cohorts{
	my($self) = shift;
	return $self->{cohorts};
}#cohorts

sub samples{
	my($self) = shift;
	return $self->{samples};
}#cohorts

sub dir_ped{
	my($self) = shift;
	return $self->{dir_ped};
}#dir_ped

sub request_family_tree{
	my($self, $indv_id) = @_;
	my %fam;
	
	my @rq = `wget https://databases.apf.edu.au/ApfBioinformaticsRequest/webservice/requestFamilyTree?externalId='$indv_id'\\&key=UJl6BOLPO0f72cOGGK63M14H4fD3yXYz -qO -`;
	for(my $i = 0; $i < scalar @rq; $i++){
		$rq[$i] =~ s/[\r\n]//g;
	}
	modules::Exception->throw("web request for FamilyTree for individual $indv_id failed\n") if(!@rq || scalar @rq < 2);
	my @h = split '\|', shift @rq;
	my %h;
	for(my $i = 0; $i < scalar @h; $i++){
		#warn "$h[$i] = $i\n";
		$h{$h[$i]} = $i;
	}
	foreach(@rq){
		#chomp;
		my @indv = split '\|', $_;
		#print STDERR "   $_";

		#awfully irritating: deal with multiple sample names, keep only the name provided in the tsv file:
		my $iid = $indv[$h{IndividualName}];
		my $fid = $indv[$h{FatherName}];
		my $mid = $indv[$h{MotherName}];
		foreach my $smpl(keys %{$self->samples}){
			$iid = $1 if($iid =~ /\b($smpl)\b/); #\b is a word break to avoid matching eg. CCG21 with CCG213
			$fid = $1 if($fid =~ /\b($smpl)\b/);
			$mid = $1 if($mid =~ /\b($smpl)\b/);
		}
		
		#singles don't have family id, assign sample id as family id
		if(!defined $indv[$h{FamilyId}] || $indv[$h{FamilyId}] eq ''){
			$indv[$h{FamilyId}] = "single:$iid";
		}
		else{
			$indv[$h{FamilyId}] = "family:$indv[$h{FamilyId}]";
		}
		
		#load our familly hash:
		$fam{$indv[$h{FamilyId}]}{$iid}{father}       = $fid ne ''? $fid: 0;
		$fam{$indv[$h{FamilyId}]}{$iid}{mother}       = $mid ne ''? $mid: 0;
		$fam{$indv[$h{FamilyId}]}{$iid}{sex}          = uc($indv[$h{Gender}])        eq 'MALE'? 1: uc($indv[$h{Gender}]) eq 'FEMALE'? 2: -9;
		$fam{$indv[$h{FamilyId}]}{$iid}{phenotype}    = uc($indv[$h{Affected}])      eq 'YES'? 2: 1;
		$fam{$indv[$h{FamilyId}]}{$iid}{apfdbid}      = $indv[$h{PatientDatabaseId}] ne ''? $indv[$h{PatientDatabaseId}]: 'NA';
		$fam{$indv[$h{FamilyId}]}{$iid}{apfrequestid} = $indv[$h{RequestId}]         ne ''? $indv[$h{RequestId}]: undef;
		
		$self->{samples}{$indv_id}{famid} = $indv[$h{FamilyId}];
		
		#comment out below to allow for samples with unknow sex:
		modules::Exception->throw("Gender of individual ".$indv[$h{IndividualName}]." has not been set in APF VariantDb (".$indv[$h{Gender}].")") if($fam{$indv[$h{FamilyId}]}{$iid}{sex} == -9);
	}
	return \%fam;
}#requestFamilyTree

sub request_family_trees{
	my($self) = @_;
	my %cohorts;
	
	warn "requesting family trees from APF\n";
	foreach(keys %{$self->samples}){
		#print STDERR " sample: $_\t";
		my $fam  = $self->request_family_tree($_);
		my $famid = (keys %{$fam})[0];
		#print STDERR "family: $famid\n";
		$cohorts{$famid} = $fam->{$famid};
	}
	foreach my $famid (keys %cohorts){
		#warn "$famid\n";
		foreach my $iid(keys %{$cohorts{$famid}}){
			#warn "$iid = $cohorts{$famid}{$iid}{father} $cohorts{$famid}{$iid}{mother}\n";
			if(!defined $self->samples->{$iid}){
				foreach (keys %{$cohorts{$famid}}){
					$cohorts{$famid}{$_}{father} = 0 if($cohorts{$famid}{$_}{father} eq $iid);
					$cohorts{$famid}{$_}{mother} = 0 if($cohorts{$famid}{$_}{mother} eq $iid);
				}
				warn "*** WARNING: Individual $iid, member of APF family $famid (".join(", ", keys %{$cohorts{$famid}}).") is not present in the input data_file. ***\n";
				delete $cohorts{$famid}{$iid};
			}
		}
	}
	warn "cohorts to be processed:\n";
	foreach my $famid (keys %cohorts){
		warn " $famid\n";
		foreach(keys %{$cohorts{$famid}}){
			warn "  $_ father: $cohorts{$famid}{$_}{father} mother: $cohorts{$famid}{$_}{mother}\n";
		}
	}
	$self->{cohorts} = \%cohorts;
}#request_family_trees

sub pedx{
	my($self, $famid, $cohort_id, $fname) = @_;
	my @pedx;
	push @pedx, ['#Cohort_ID', 'Individual_ID', 'Paternal_ID', 'Maternal_ID', 'Sex', 'Phenotype', 'Capture_Kit', 'APFdb_ID', 'APFrequest_ID'];
	my $fam = $self->cohorts->{$famid};
	foreach(sort keys %{$fam}){
		my $apfrequestid = $fam->{$_}{apfrequestid};
		
		#if requested, get the newest request id from the list:
		if($self->{samples}{$_}{requestid} eq 'NEW'){
			if(defined $apfrequestid){
				my @a = split ",", $apfrequestid;
				@a = sort{$b <=> $a} @a;
				$apfrequestid = $a[0];
				warn "individual $_ has several seq. requests assigned (".join(', ', sort{$a <=> $b} @a)."), choosing the newest - $apfrequestid\n" if(scalar @a > 1);
			}
			else{ #or 'NA' if request not available
				$apfrequestid = 'NA';
			}
		}
		else{
			$apfrequestid = $self->{samples}{$_}{requestid};
		}
		push @pedx, [$cohort_id, $_, $fam->{$_}{father}, $fam->{$_}{mother}, $fam->{$_}{sex}, $fam->{$_}{phenotype}, $self->{samples}{$_}{kit}, $fam->{$_}{apfdbid}, $apfrequestid]	
	}
	if(defined $fname){
		warn "writing pedx file $fname\n";
		open O, ">$fname" or modules::Exception->throw("Can't open $fname for writing\n");
		foreach(@pedx){
			print O join("\t", @$_)."\n";
		}
		close O;
	}
	return \@pedx;
}#pedx

sub get_data_tsv{
	my($self, $fname, $fqdir) = @_;
	
	my $dir_reads   = $self->config->read("directories", "reads");
	my $read_regex1 = $self->config->read("global", "read_regex1");
	my $read_regex2 = $self->config->read("global", "read_regex2");

	my %smpl;
	
	$self->{dir_ped} = dirname(abs_path($fname));
	$fqdir = dirname(abs_path($fname)) if(!defined $fqdir);
	
	print STDERR "$fname: processing data:\n";
	open F, "$fname" or modules::Exception->throw("Can't open $fname");
	my $cnt = 0;
	while(<F>){
		chomp;
		next if(/^#/);
		my @s = split "\t";
		next if(!scalar @s);
		$smpl{$s[0]}{kit} = defined $s[1] && $s[1] ne ''? $s[1]: 'WGS';
		$smpl{$s[0]}{requestid} = defined $s[2] && $s[2] ne ''? $s[2]: '';
		$smpl{$s[0]}{cnt}++;
		$cnt++;
		#warn "sample: $s[0]\n";
		for(my $i = 3; $i < scalar @s; $i++){
			my $r1 = $s[$i];
			$r1 =~ /^(.*)($read_regex2)/;
			my $fp = $1;
			my $rp = $2;
			$rp =~ s/1/2/;
			my $r2 = $r1;
			#warn "$r2 =~ s/$read_regex2/$rp/\n";
			$r2 =~ s/$read_regex2/$rp/;
			warn " $s[0]\tfastq: $r1, $r2\n";
			$r1 = "$fqdir/$r1";
			$r2 = "$fqdir/$r2";
			modules::Exception->throw("Can not access file $r1") if(!-e $r1);
			modules::Exception->throw("Can not access file $r2") if(!-e $r2);
			push @{$smpl{$s[0]}{fq}}, [$r1, $r2]
		}
	}
	close F;
	
	print STDERR "$fname: read $cnt lines and loaded ".(scalar keys %smpl)." sample ids\n";
	my $bad;
	foreach(sort keys %smpl){
		if($smpl{$_}{cnt} > 1){
			warn "ERROR: sample $_ present $smpl{$_}{cnt} times\n";
			$bad = 1;
		}
	}
	modules::Exception->throw("Sample(s) with the same id were present more than once.\nIf you want to analyze the same sample(s) more than once\nyou will need to put them in separate tsv files.") if($bad);
	$self->{samples} = \%smpl;
}#get_data_tsv

1
