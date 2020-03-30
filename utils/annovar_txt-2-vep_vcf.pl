#! /usr/bin/perl -w 
use strict;
use Data::Dumper;
use Pod::Usage;

=head1 SYNOPSIS

<name>.pl

Required flags: NONE

=head1 OPTIONS

=head1 NAME

=head1 DESCRIPTION

March 2020

a script that ...

=head1 AUTHOR

Marcin Adamski

=head1 EXAMPLE

=cut

my @fld;
my $cbeg = 5;
while(<>){
	chomp;
	my @a = split "\t";
	if(/^#/){
		@fld = @a;
		#print "$_\n";
		print"##fileformat=VCFv4.2\n#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\n";
		next;
	}
	my $info;
	for(my $i = $cbeg; $i < scalar @a; $i++){
		$info .= ';' if(defined $info);
		$info .= "$fld[$i]=$a[$i]";
	}
	$a[2] = '.';
	$info = join("\t", @a[0..($cbeg -1)])."\t.\t.\t$info";
	#print "$_\n";
	print "$info\n";
	#last;
}#while