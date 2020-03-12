#! /usr/bin/perl -w 
use strict;
use Getopt::Long;
use Pod::Usage;
use modules::Definitions;
use modules::Exception;
use modules::Utils;

use vars qw(%OPT);

GetOptions(\%OPT, 
	   		"help|h",
	   		"man|m",
	   		"file=s",
	   		"status=s",
	   		"data:s"
	   		);
	   		
pod2usage(-verbose => 2) if $OPT{man};
pod2usage(1) if ($OPT{help});

=pod

=head1 SYNOPSIS

pipe_status.pl 

=head1 OPTIONS

    -help  brief help message
    -man   full documentation

=head1 NAME

pipe_status.pl -> Does something useful

=head1 DESCRIPTION

Fab 2020

a script that ...

=head1 AUTHOR

Marcin Adamski

=head1 EXAMPLE

./pipe_status.pl

=cut

my $fname = $OPT{file};
my $status = $OPT{status};
my $data = $OPT{data};

modules::Exception->throw("$0 needs arguments --file --status [--data]") if(!defined $fname || !defined $status);
$data = '' if(!defined $data);
	
my $oh;
open($oh, ">>", $fname) or modules::Exception->throw("Can't open $fname for writing\n");
$oh->autoflush(1);
print $oh "".modules::Utils::get_time_stamp()."\t$status\t$data\n";
close $oh;
