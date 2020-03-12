package modules::Utils;

use strict;
use modules::Definitions;
use modules::Exception;
use Data::Dumper;
use File::Basename;
use POSIX;

#use constant TIMESTAMP => '%d-%m-%Y_%H:%M:%S';

sub confdir{
	my($self) = shift;
	my $d = dirname(__FILE__);
	$d =~ s/[^\/]*$/conf/;
	modules::Exception->throw("Can't access configuration directory '$d'") if(!-d $d);
	return $d;
}#confdir

sub scriptdir{
	my($self) = shift;
	my $d = dirname(__FILE__);
	$d =~ s/[^\/]*$/scripts/;
	modules::Exception->throw("Can't access script directory '$d'") if(!-d $d);
	return $d;
}#scriptdir

sub hostname{
	my($self) = shift;
	my $name = Sys::Hostname::hostname();
	$name =~ /^([^\.]+)/;
	return $1;
}#hostname

sub median() {
    my ($self, $ra_values) = @_;

    my @sorted = sort {$a <=> $b} @$ra_values;

    my $length = scalar @sorted;

    if ($length%2 == 0 && $length >2){
    	return ($sorted[($length/2 - 1)] + $sorted[($length/2)])/2;
    } elsif ($length == 2) {
    	return ($sorted[0] + $sorted[1])/2;
    } else {
    	return $sorted[$length/2];
    }
}#median

sub quartiles() {
    my ($self, $ra_values) = @_;

    my @sorted = sort {$a <=> $b} @$ra_values;

    my $length = scalar @sorted;

    my $second_quartile = $self->median($ra_values);

    my $first_quartile;
    my $third_quartile;

    # Calculating quartiles excluding the value(s) used to calculate the overall median
    if ($length%2 == 0 && $length > 4){
		my @subset = @sorted[0..(($length/2)-2)];
		$first_quartile = $self->median(\@subset);
		@subset = @sorted[($length/2)..$length-1];
		$third_quartile = $self->median(\@subset);
    } elsif ($length <= 4) {
	  	modules::Exception->warning("Choosing not to calculate quartiles on four or fewer values");
	  	return [undef, undef, undef, undef, undef];
    } else {
		my @subset = @sorted[0..int($length/2)-1];
		$first_quartile = $self->median(\@subset);
		@subset = @sorted[(int($length/2)+1)..$length-1];
		$third_quartile = $self->median(\@subset);
    }

    my $min_value = $sorted[0];
    my $max_value = $sorted[-1];

    return [$min_value, 
	    $first_quartile, 
	    $second_quartile, 
	    $third_quartile, 
	    $max_value];
}#quartiles


sub min() {
	my ($self, $ra_values) = @_;
	my @sorted = sort {$a <=> $b} @$ra_values;
	return $sorted[0];
}#min

sub max() {
	my ($self, $ra_values) = @_;
	my @sorted = sort {$a <=> $b} @$ra_values;
	return $sorted[-1];
}#max

sub get_time_stamp{
	return POSIX::strftime(TIMESTAMP, localtime);
}#get_time_stamp


sub get_cohorts{
	my($dir_cohort, $status) = @_;
	my @cohorts;
	
	modules::Exception->throw("must know status of the cohorts") if(!defined $status);
	modules::Exception->throw("unknow status request '$status'") if($status ne 'all' && $status ne 'in_progress' && $status ne 'finished');
	
	modules::Exception->throw("Can't access cohorts directory $dir_cohort") if(!-d $dir_cohort);
	opendir(DIR, $dir_cohort) or modules::Exception->throw("Can't open cohorts directory $dir_cohort");
	while(readdir(DIR)){
		next if(/^\./);
		next if(!-e "$dir_cohort/$_/pipeline.cnf");
		next if($status eq 'in_progress' && -e "$dir_cohort/$_/pipeline.finished");
		next if($status eq 'finished' && !-e "$dir_cohort/$_/pipeline.finished");
		push @cohorts, $_;
	}
	closedir(DIR);
	return @cohorts;
}#get_cohorts

sub translate {
	my ($self, $rna) = @_;
	my %genetic_code = (
			'TCA' => 'S', # Serine
			'TCC' => 'S', # Serine
			'TCG' => 'S', # Serine
			'TCT' => 'S', # Serine
			'TTC' => 'F', # Phenylalanine
			'TTT' => 'F', # Phenylalanine
			'TTA' => 'L', # Leucine
			'TTG' => 'L', # Leucine
			'TAC' => 'Y', # Tyrosine
			'TAT' => 'Y', # Tyrosine
			'TAA' => '_', # Stop
			'TAG' => '_', # Stop
			'TGC' => 'C', # Cysteine
			'TGT' => 'C', # Cysteine
			'TGA' => '_', # Stop
			'TGG' => 'W', # Tryptophan
			'CTA' => 'L', # Leucine
			'CTC' => 'L', # Leucine
			'CTG' => 'L', # Leucine
			'CTT' => 'L', # Leucine
			'CCA' => 'P', # Proline
			'CAT' => 'H', # Histidine
			'CAA' => 'Q', # Glutamine
			'CAG' => 'Q', # Glutamine
			'CGA' => 'R', # Arginine
			'CGC' => 'R', # Arginine
			'CGG' => 'R', # Arginine
			'CGT' => 'R', # Arginine
			'ATA' => 'I', # Isoleucine
			'ATC' => 'I', # Isoleucine
			'ATT' => 'I', # Isoleucine
			'ATG' => 'M', # Methionine
			'ACA' => 'T', # Threonine
			'ACC' => 'T', # Threonine
			'ACG' => 'T', # Threonine
			'ACT' => 'T', # Threonine
			'AAC' => 'N', # Asparagine
			'AAT' => 'N', # Asparagine
			'AAA' => 'K', # Lysine
			'AAG' => 'K', # Lysine
			'AGC' => 'S', # Serine
			'AGT' => 'S', # Serine
			'AGA' => 'R', # Arginine
			'AGG' => 'R', # Arginine
			'CCC' => 'P', # Proline
			'CCG' => 'P', # Proline
			'CCT' => 'P', # Proline
			'CAC' => 'H', # Histidine
			'GTA' => 'V', # Valine
			'GTC' => 'V', # Valine
			'GTG' => 'V', # Valine
			'GTT' => 'V', # Valine
			'GCA' => 'A', # Alanine
			'GCC' => 'A', # Alanine
			'GCG' => 'A', # Alanine
			'GCT' => 'A', # Alanine
			'GAC' => 'D', # Aspartic Acid
			'GAT' => 'D', # Aspartic Acid
			'GAA' => 'E', # Glutamic Acid
			'GAG' => 'E', # Glutamic Acid
			'GGA' => 'G', # Glycine
			'GGC' => 'G', # Glycine
			'GGG' => 'G', # Glycine
			'GGT' => 'G'  # Glycine
			);
	my ($protein) = '';
	for(my $i=0;$i<length($rna)-2;$i+=3)
	{
		my $codon = substr($rna,$i,3);
		$protein .= $genetic_code{$codon};
	}
	return $protein;
}#translate 

sub revcom {
	my ( $self, $seq ) = @_;
    my $revcomp = reverse($seq);
  	$revcomp =~ tr/ACGTacgt/TGCAtgca/;
  	return $revcomp;
}#revcom 

sub isarray{
	return ref(shift) eq 'ARRAY'? 1: 0
}#isarray

sub pbs_qsub{
	#_pbs_qsub_dummy(@_);
	_pbs_qsub_actual(@_);
}#pbs_qsub

sub _pbs_qsub_dummy{
	my($qsub_file) = @_;
	warn "    *** run: qsub $qsub_file ***\n";
	return(0, 'foo_jobid');
}#_pbs_qsub_dummy

sub _pbs_qsub_actual{
	my($qsub_file) = @_;

	my $cmd = "qsub $qsub_file";
	my $out = qx($cmd 2>&1);
  my $ret = $?;
	modules::Exception->warning("Command '$cmd' failed; job was NOT submitted") if($ret);
	chomp $out;
	return($ret, $out);
}#_pbs_qsub_actual

sub pbs_qjobs{
	my %jobs;
	
	my $cmd = "qstat -u \$(whoami)"; #in gadi's current configuration '-u <username>' is not necessary as qstat only returns jobs from current user. to get info on finished jobs as well add '-x'
	warn "quering PBS jobs status...\n";
	my @out = qx($cmd 2>&1);
  my $ret = $?;
	if($ret){
		modules::Exception->warning("Command '$cmd' failed; no data on PBS queue job status") 
	}
	else{
		foreach(@out){
			next if(!/^\d+/);
			s/\s+/\t/g;
			my @a = split "\t";
			$jobs{$a[0]} = $a[9];
			#warn "$_ => $a[0] = $a[9]\n";
		}
	}
	warn "number of jobs in the queues: ".(scalar keys %jobs)."\n";
	return(\%jobs);
}#pbs_qjobs

sub pbs_ncpu{
	return($ENV{'PBS_NP'});
}#pbs_ncpu

sub pbs_jobid{
	return($ENV{'PBS_JOBID'});
}#pbs_jobid

return 1;
