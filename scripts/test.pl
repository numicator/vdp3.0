#! /usr/bin/perl -w 
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Path qw(make_path remove_tree);
use File::Basename;
use Pod::Usage;
use Cwd;
use Excel::Writer::XLSX;
use modules::Definitions;
use modules::SystemCall;
use modules::Exception;
use modules::Config;
use modules::PED;
use modules::Pipeline;
use modules::Cohort;
use modules::Utils;
use modules::Semaphore;

my $workbook  = Excel::Writer::XLSX->new('test.xlsx') or modules::Exception->throw("Can't write to 'test.xlsx'");
my $worksheet = $workbook->add_worksheet('SNV');
my $header    = $workbook->add_format(bold => 1);

my $row = 0;
my $col = 0;
while(<>){
	print STDERR "$row: ";
	chomp;
	my @a = split "\t";
	$col = scalar @a - 1 if(!$col);
	for(my $inx = 0; $inx < scalar @a; $inx++){
		#print STDERR "$inx ";
		my $v = $a[$inx];
		$worksheet->write($row, $inx, $v, $row == 0? $header: undef);
	}
	print STDERR "\n";
	$row++;
}
$worksheet->autofilter(0, 0, 0, $col);
$workbook->close();