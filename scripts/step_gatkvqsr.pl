#! /usr/bin/perl -w 
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Path qw(make_path remove_tree);
use File::Basename;
use Pod::Usage;
use Cwd;
use modules::Definitions;
use modules::SystemCall;
use modules::Exception;
use modules::Config;
use modules::PED;
use modules::Pipeline;
use modules::Cohort;
use modules::Utils;
use modules::Semaphore;

use vars qw(%OPT);


GetOptions(\%OPT, 
	   		"help|h",
	   		"man|m",
	   		"config=s",
	   		"step=s",
	   		"cohort=s",
	   		"individual=s",
	   		"readfile=s",
	   		"split=s",
	   		"fun=s",
	   		"mode=s",
	   		"exit=s"
	   		);
	   		
pod2usage(-verbose => 2) if $OPT{man};
pod2usage(1) if ($OPT{help});

	   
=pod

=head1 SYNOPSIS

step_<name>.pl

Required flags: NONE

=head1 OPTIONS

    -config  path to cohort configuration file
    -cohort  cohort name
    -help    brief help message
    -man     full documentation

=head1 NAME

step_<name>.pl -> Does something useful

=head1 DESCRIPTION

Fab 2020

a script that ...

=head1 AUTHOR

Marcin Adamski

=head1 EXAMPLE

./step_<name>.pl

=cut

my $step       = $OPT{step};
my $split      = $OPT{'split'};
my $cohort     = $OPT{cohort};
my $individual = $OPT{individual};
#script specific args:
my $fun        = $OPT{fun};
my $mode       = $OPT{mode};

die("this script requires at least arguments --cohort <cohort> and --step <step>\nrun: $0 --help to hopefully get some brief help\n") if(!defined $cohort | !defined $step);

warn "running pipeline step '$step".(defined $split? $split: '')."' on cohort '$cohort'\n";
modules::Exception->throw("need argument --fun <recal|apply>") if(!defined $fun);

my $Config   = modules::Config->new($OPT{config});
my $Syscall  = modules::SystemCall->new();

my $pversion = $Config->read("global", "version");
my $codebase = $Config->read("directories", "pipeline");
warn "pipeline version: '$pversion', codebase: '$codebase'\n";

my $dir_cohort  = $Config->read("cohort", "dir");
modules::Exception->throw("Can't access cohort directory $dir_cohort") if(!-d $dir_cohort);
my $dir_run = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:$step", "dir");
modules::Exception->throw("Can't access cohort run directory $dir_run") if(!-d $dir_run);
my $dir_tmp = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("directories", "tmp");
modules::Exception->throw("Can't access cohort run TEMP directory $dir_tmp") if(!-d $dir_tmp);
my $dir_gvcfs = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:split:gatk_genotype_gvcfs", "dir");
modules::Exception->throw("Can't access cohort run directory $dir_gvcfs") if(!-d $dir_gvcfs);
my $regions = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:merge_target", "dir").'/regions.bed';
modules::Exception->throw("Can't access call regions file $regions") if(!-e $regions);

my $PED = modules::PED->new("$dir_cohort/$cohort.pedx");
modules::Exception->throw("cohort PED file must contain exactly one family") if(scalar keys %{$PED->ped} != 1);
modules::Exception->throw("cohort id submited as argument is not the same as cohort id in PED: '$cohort' ne '".(keys %{$PED->ped})[0]."'") if((keys %{$PED->ped})[0] ne $cohort);

my $Cohort = modules::Cohort->new("$cohort", $Config, $PED);
$Cohort->add_individuals_ped();
#my $Pipeline = modules::Pipeline->new(cohort => $Cohort);
#$Pipeline->get_pipesteps;
#$Pipeline->get_qjobs;

if($fun eq 'recal'){
	recal();
}
else{
	apply()
}
exit(0);

####################################################################################################
# VariantRecalibrator
#
sub recal{
	my $reference   = $Config->read("references", "genome_fasta");
	my $tranche     = $Config->read("step:$step", "tranche");
	my $annotation  = $Config->read("step:$step", "annotation");
	my $resources   = $Config->read("step:$step", "resources");
	my $gauss       = $Config->read("step:$step", "gauss");
	my $makeplots   = $Config->read("step:$step", "makeplots");
	my $plots_bin   = $Config->read("step:$step", "plots_bin");
	
	$tranche    = ",$tranche";
	$annotation = ",$annotation";
	$resources  = ";$resources";
	$tranche =~ s/[,;]/ -tranche /g;
	$annotation =~ s/[,;]/ -an /g;
	$resources  =~ s/;/ -resource:/g;
	my @gausses = split /[,;]/, $gauss;

	#get all split vcf files for recalibration, recalibration is run on all spit vcfs together:
	my @files;
	foreach(sort keys %{$Config->read("split")}){
		my $f = "$dir_gvcfs/$cohort.$_.all.vcf.gz";
		modules::Exception->throw("Can't access file '$f'") if(!-e $f);
		modules::Exception->throw("File '$f' is empty") if(!-s $f);
		push @files, $f;
	}

	#--max-gaussians is a tricky argument, gatk tends to fail if it was set to high, we are trying several values from the config file and accepting the first success 
	my $r = -1;
	foreach my $g(@gausses){
		warn "running with --max-gaussians $g\n";
		my $cmd = $Config->read("step:$step", "gatk_bin");
		my $cmdx = " VariantRecalibrator -mode $mode --tmp-dir $dir_tmp -R $reference -L $regions $tranche $annotation $resources --max-gaussians $g --trust-all-polymorphic -V ".join(" -V ", @files)." --tranches-file $dir_run/$cohort.$mode.all.tranches -O $dir_run/$cohort.$mode.recall.all.vcf.gz";
		$cmdx =~ s/\s+-/ \\\n  -/g;
		$cmd .= $cmdx;
		#warn "$cmd\n"; exit(PIPE_NO_PROGRESS);
		$r = $Syscall->run($cmd, 1);
		if($r){
			warn "run with --max-gaussians $g FAILED\n";
		}
		else{
			last;
		}
	}
	exit(1) if($r); #exit with $r would be tricky as bash sees only 8 bits, instead of converting we just return 1
	
	my $cmd = "gzip -t $dir_run/$cohort.$mode.recall.all.vcf.gz";
	$r = $Syscall->run($cmd);
	exit(1) if($r);
	
	if($makeplots eq 'true'){
		$cmd = "$plots_bin $dir_run/$cohort.$mode.all.tranches";
		$r = $Syscall->run($cmd, 1);
		exit(1) if($r);
	}
}#recal


####################################################################################################
# ApplyVQSR
#
sub apply{
	my $reference   = $Config->read("references", "genome_fasta");
	my $split_bed   = $Config->read($Config->read("split", $split), "bed");
	my $filter = $Config->read("step:$step", "sensitivity_cutoff");

	my $cmd = $Config->read("step:$step", "gatk_bin");
	my $bcftools = $Config->read("step:$step", "bcftools_bin");
	my $tabix    = $Config->read("step:$step", "tabix_bin");

	my $variant = $mode eq 'INDEL'? "$dir_gvcfs/$cohort.$split.all.vcf.gz": "$dir_run/$cohort.$split.INDEL.all.vqsr.vcf.gz";
	my $fo      = "$dir_run/".($mode eq 'INDEL'? "$cohort.$split.$mode.all.vqsr.vcf.gz": "$cohort.$split.all.vqsr.vcf.gz");
	my $fout    = $mode eq 'INDEL'? $fo: "/dev/stdout | $bcftools view -f PASS -O z - -o $fo";

	modules::Exception->throw("'$variant' file not found - this step must be first run in -mode INDEL and only then in -mode SNP") if($mode eq 'SNP' && !-e $variant);

	my @indv;
	foreach(sort @{$Cohort->individual}){
		push @indv, $_->id;
	}
	my $r;
	#--create-output-variant-index true
	my $cmdx = " ApplyVQSR -mode $mode --tmp-dir $dir_tmp -L $regions -L $split_bed --truth-sensitivity-filter-level $filter --create-output-variant-index false --tranches-file $dir_run/$cohort.$mode.all.tranches --recal-file $dir_run/$cohort.$mode.recall.all.vcf.gz -V $variant -O $fout";
	$cmdx =~ s/\s+-/ \\\n  -/g;
	$cmd .= $cmdx;
	#warn "$cmd\n"; exit(PIPE_NO_PROGRESS);
	$r = $Syscall->run($cmd);
	exit(1) if($r);

	$cmd = "gzip -t $fo";
	$r = $Syscall->run($cmd);
	exit(1) if($r);

	$cmd = "$tabix -f $fo";
	$r = $Syscall->run($cmd);
	exit(1) if($r);
	
	#select samples and variants from the cohort
	if($mode eq 'SNP'){
		$cmd = $Config->read("step:$step", "gatk_bin");
		$cmdx = " SelectVariants --tmp-dir $dir_tmp -R $reference -V $dir_run/$cohort.$split.all.vqsr.vcf.gz -O $dir_run/$cohort.$split.vqsr.vcf.gz -sn ".join(" -sn ", @indv)." --exclude-non-variants true"; # --remove-unused-alternates true"; #SelectVariants can't properly deal with INFO/AS_BaseQRankSum fields
		$cmdx =~ s/\s+-/ \\\n  -/g;
		$cmd .= $cmdx;
		#warn "$cmd\n"; exit(PIPE_NO_PROGRESS);
		$r = $Syscall->run($cmd);
		exit(1) if($r);
		$cmd = "gzip -t $dir_run/$cohort.$split.vqsr.vcf.gz";
		$r = $Syscall->run($cmd);
		exit(1) if($r);
	}
}#apply

END{
	warn "done script ".basename(__FILE__)."\n"
}
