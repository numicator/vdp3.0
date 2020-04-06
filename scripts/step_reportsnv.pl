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

die("this script requires at least arguments --cohort <cohort> and --step <step>\nrun: $0 --help to hopefully get some brief help\n") if(!defined $cohort | !defined $step);

warn "running pipeline step '$step".(defined $split? $split: '')."' on cohort '$cohort'\n";

my $Config   = modules::Config->new($OPT{config});
my $Syscall  = modules::SystemCall->new();

my $pversion = $Config->read("global", "version");
my $codebase = $Config->read("directories", "pipeline");
warn "pipeline version: '$pversion', codebase: '$codebase'\n";

my $dir_cohort  = $Config->read("cohort", "dir");
modules::Exception->throw("Can't access cohort directory $dir_cohort") if(!-d $dir_cohort);
my $dir_run = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:$step", "dir");
modules::Exception->throw("Can't access cohort run directory $dir_run") if(!-d $dir_run);
my $dir_result = $dir_cohort.'/'.$Config->read("directories", "result");
modules::Exception->throw("Can't access cohort run directory $dir_result") if(!-d $dir_result);
my $dir_tmp = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("directories", "tmp");
modules::Exception->throw("Can't access cohort run TEMP directory $dir_tmp") if(!-d $dir_tmp);
my $dir_peddy = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:$step", "peddy_dir");
my $regions = $dir_cohort.'/'.$Config->read("directories", "run").'/'.$Config->read("step:merge_target", "dir").'/regions.bed';
modules::Exception->throw("Can't access call regions file $regions") if(!-e $regions);

my $PED = modules::PED->new("$dir_cohort/$cohort.pedx");
modules::Exception->throw("cohort PED file must contain exactly one family") if(scalar keys %{$PED->ped} != 1);
modules::Exception->throw("cohort id submited as argument is not the same as cohort id in PED: '$cohort' ne '".(keys %{$PED->ped})[0]."'") if((keys %{$PED->ped})[0] ne $cohort);
#my $Cohort = modules::Cohort->new("$cohort", $Config, $PED);
#$Cohort->add_individuals_ped();
#my $Pipeline = modules::Pipeline->new(cohort => $Cohort);
#$Pipeline->get_pipesteps;
#$Pipeline->get_qjobs;

my $reference = $Config->read("references", "genome_fasta");
my $dict = $reference;
$dict =~ s/\.fa(sta)*$/\.dict/;

my $dbsnp = $Config->read("step:$step", "dbsnp");
my $filter_rd_cvr = $Config->read("step:$step", "filter_rd_cvr");

my $bgzip_bin  = $Config->read("step:$step", "bgzip_bin");
my $tabix_bin  = $Config->read("step:$step", "tabix_bin");
my $picard_bin = $Config->read("step:$step", "picard_bin");
my $gatk_bin   = $Config->read("step:$step", "gatk_bin");
my $peddy_bin  = $Config->read("step:$step", "peddy_bin");
my $pcaplot_bin= $Config->read("step:$step", "pcaplot_bin");

my @files;
foreach(sort keys %{$Config->read("split")}){
	my $f = "$dir_run/$cohort.$_.vep.tsv";
	modules::Exception->throw("Can't access file '$f'") if(!-e $f);
	modules::Exception->throw("File '$f' is empty") if(!-s $f);
	push @files, $f;
}

my $sort_bin = "for f in ".join(' ', @files)."; do tail -n +2 \$f; done | sort -S 4G -k1,1V -k2,2n -k3,3 |";
my $head_bin = "head -n 1 $files[0] |";
my $all_bin = "| $bgzip_bin -c >$dir_run/$cohort.vep_all.tsv.gz";
my $coding_bin = "| $bgzip_bin -c >$dir_run/$cohort.vep_coding.tsv.gz";
my $stats_out  = ">$dir_run/$cohort.stats.tsv";

my $r;
my $cmd;

warn "creating final TSV reports\n";

open I, "$head_bin" or modules::Exception->throw("Can't do: '$head_bin'");

my @head;
my %fld;
while(<I>){
	chomp;
	@head = split "\t";
	for(my $i = 0; $i < scalar @head; $i++){
		$fld{$head[$i]} = $i;
	}
}
close I;

#use of variables instead of hash for faster access:
my $fld_Protein_position   = $fld{Protein_position};
my $fld_Consequence        = $fld{Consequence};
my $fld_Existing_variation = $fld{Existing_variation};

my $fld_chr = $fld{chr};
my $fld_pos = $fld{pos};
my $fld_ref = $fld{ref};
my $fld_RD  = $fld{RD};
my $fld_alt = $fld{alt};
my $fld_caller = $fld{caller};

#extras I have used in tests, to better understand the report
#my $fld_pos        = $fld{pos};
#my $fld_GIVEN_REF  = $fld{GIVEN_REF};
#my $fld_USED_REF   = $fld{USED_REF};

open I, "$sort_bin" or modules::Exception->throw("Can't do: '$sort_bin'");
open ALL, "$all_bin" or modules::Exception->throw("Can't do: '$all_bin'");
open CODING, "$coding_bin" or modules::Exception->throw("Can't do: '$coding_bin'");

@head = (@head[0..($fld_RD - 1)], "FILTER", @head[$fld_RD..$#head]);
print ALL join("\t", @head)."\n";
print CODING join("\t", @head)."\n";

my %stats;
my $posp;
while(<I>){
	chomp;
	my @a = split "\t";

	my($is_cvrok, $is_snp, $is_known, $is_multi, $is_ti, $is_coding, $caller);

	$is_cvrok  = $a[$fld_RD] >= $filter_rd_cvr? 1: 0;
	$is_coding = (defined $a[$fld_Protein_position] && $a[$fld_Protein_position] ne '') || (defined $a[$fld_Consequence] && $a[$fld_Consequence] =~ /splice_/)? 1: 0;
	
	#stats are calculated only for filtered variants:
	if($is_cvrok){
		$caller = $a[$fld_caller];
		$stats{$caller}++;
		#flags describing the variant:
		$is_snp   = length($a[$fld_ref]) == 1 && length($a[$fld_alt]) == 1? 1: 0;
		$is_known = defined $a[$fld_Existing_variation] && $a[$fld_Existing_variation] ne ''? 1: 0;
		$is_multi = defined $posp && $posp == $a[$fld_pos]? 1: 0;
		#Caluclate Ti: A-G G-A C-T T-C #Tv: A-T T-A G-C C-G G-T T-G A-C C-A
		if($is_snp){
			my $r = uc($a[$fld_ref]);
			my $a = uc($a[$fld_alt]);
			$is_ti = ($r eq 'A' && $a eq 'G') || ($r eq 'G' && $a eq 'A') || ($r eq 'C' && $a eq 'T') || ($r eq 'T' && $a eq 'C') ? 1: 0;
		}
		#stats for all variants:
		if($is_multi){
			$stats{multi}++;
		}
		else{
			if($is_snp){
				$stats{snp}++;
				$stats{ti}++ if($is_ti);
			}
			else{
				$stats{indel}++;
			}
			if($is_known){
				$stats{known}++;
				if($is_snp){
					$stats{snp_known}++;
					$stats{ti_known}++ if($is_ti);
				}
			}
			else{
				$stats{novel}++;
				if($is_snp){
					$stats{snp_novel}++;
					$stats{ti_novel}++ if($is_ti);
				}
			}
		}	
		#and stats for coding variants:
		if($is_coding){
			if($is_multi){
				$stats{multi_coding}++;
			}
			else{
				if($is_snp){
					$stats{snp_coding}++;
					$stats{ti_coding}++ if($is_ti);
				}
				else{
					$stats{indel_coding}++;
				}
				if($is_known){
					$stats{known_coding}++;
					if($is_snp){
						$stats{snp_known_coding}++;
						$stats{ti_known_coding}++ if($is_ti);
					}
				}
				else{
					$stats{novel_coding}++;
					if($is_snp){
						$stats{snp_novel_coding}++;
						$stats{ti_novel_coding}++ if($is_ti);
					}
				}
			}	
		}#if($is_coding)
		$posp = $a[$fld_pos];
	}#if($is_cvrok)
	else{
		$stats{bad_cover}++;
		$stats{bad_cover_coding}++ if($is_coding);
	}#else if($is_cvrok)
	@a = (@a[0..($fld_RD - 1)], ($is_cvrok? 'ok': "RD_CVR<$filter_rd_cvr"), @a[$fld_RD..$#a]);
	print ALL join("\t", @a)."\n";
	print CODING join("\t", @a)."\n" if($is_coding);
}#while(<I>)
close ALL;
close CODING;
close I;

open STATS, "$stats_out" or modules::Exception->throw("Can't do: '$stats_out'");
print STATS join("\t", sort keys %stats)."\n";
my @statsv;
foreach(sort keys %stats){
	push @statsv, $stats{$_};
}
print STATS join("\t", @statsv)."\n";
close STATS;

warn "indexing final TSV reports\n";

#tabix 
# -f force overwrite of the index file
# -p bed treat as a bed file
# -S 1 skip single header line
# -s 1 first line has seq names
# -b 2 -e 2 positions to index are in column 2

$cmd = "$tabix_bin -f -p bed -S 1 -s 1 -b 2 -e 2 $dir_run/$cohort.vep_all.tsv.gz";
$r = $Syscall->run($cmd);
exit(1) if($r);

$cmd = "$tabix_bin -f -p bed -S 1 -s 1 -b 2 -e 2 $dir_run/$cohort.vep_coding.tsv.gz";
$r = $Syscall->run($cmd);
exit(1) if($r);

warn "creating final VCF files\n";
#get final vcf
undef @files;
foreach(sort keys %{$Config->read("split")}){
	my $f = "$dir_run/$cohort.$_.vcf.gz";
	modules::Exception->throw("Can't access file '$f'") if(!-e $f);
	modules::Exception->throw("File '$f' is empty") if(!-s $f);
	push @files, $f;
}
$cmd = "$picard_bin GatherVcfs TMP_DIR=$dir_tmp CREATE_INDEX=true MAX_RECORDS_IN_RAM=300000 I=".join(" I=", @files)." O=$dir_run/$cohort.vcf.gz";
$r = $Syscall->run($cmd);
exit(1) if($r);
$cmd = "$tabix_bin -f $dir_run/$cohort.vcf.gz";
$r = $Syscall->run($cmd);
exit(1) if($r);
#get final VEP vcf
undef @files;
foreach(sort keys %{$Config->read("split")}){
	my $f = "$dir_run/$cohort.$_.vep.vcf.gz";
	modules::Exception->throw("Can't access file '$f'") if(!-e $f);
	modules::Exception->throw("File '$f' is empty") if(!-s $f);
	push @files, $f;
}
$cmd = "$picard_bin GatherVcfs TMP_DIR=$dir_tmp CREATE_INDEX=true MAX_RECORDS_IN_RAM=300000 I=".join(" I=", @files)." O=$dir_run/$cohort.vep.vcf.gz";
$r = $Syscall->run($cmd);
exit(1) if($r);
$cmd = "$tabix_bin -f $dir_run/$cohort.vep.vcf.gz";
$r = $Syscall->run($cmd);
exit(1) if($r);

warn "collecting variant calling metrics\n";

#picard CollectVariantCallingMetrics refuses to take regions in BED format, needs it's own, it's simple conversion:
$cmd = "$picard_bin BedToIntervalList SD=$dict I=$regions O=$dir_run/$cohort.interval_list";
$r = $Syscall->run($cmd);
exit(1) if($r);

#picard CollectVariantCallingMetrics chokes on calls done by Varscan, most likely due to the way the AD tag is being used for not I just 
#filter out Varscan-only calls from the set; it means the metrics don't use the approx 1.5% of calls done by Varscan it should be addressed 
#properly in the future and got rid of the code below. Anyway, it's ONLY for the metrics, Varscan results are still properly reported
#BTW, we can't pipe, we need an intermediate vcf.gz as we need tabix index:
$cmd = "$bgzip_bin -dc $dir_run/$cohort.vcf.gz | grep -v \"caller=varscan;\" | $bgzip_bin -c >$dir_run/$cohort.metrics_in.vcf.gz";
$r = $Syscall->run($cmd);
exit(1) if($r);
$cmd = "$tabix_bin -f $dir_run/$cohort.metrics_in.vcf.gz";
$r = $Syscall->run($cmd);
exit(1) if($r);

#not using the Varscan filtered vcf.gz in the cmd below:
#$cmd = "$picard_bin CollectVariantCallingMetrics TMP_DIR=$dir_tmp I=$dir_run/$cohort.vcf.gz TI=$dir_run/$cohort.interval_list DBSNP=$dbsnp SD=$dict O=$dir_run/$cohort";
$cmd = "$picard_bin CollectVariantCallingMetrics TMP_DIR=$dir_tmp I=$dir_run/$cohort.metrics_in.vcf.gz TI=$dir_run/$cohort.interval_list DBSNP=$dbsnp SD=$dict O=$dir_run/$cohort";
$r = $Syscall->run($cmd);
exit(1) if($r);
unlink("$dir_run/$cohort.metrics_in.vcf.gz");
unlink("$dir_run/$cohort.metrics_in.vcf.gz.tbi");

warn "running peddy\n";
make_path("$dir_peddy");
$cmd = "$peddy_bin --procs 1 --plot --sites hg38 --prefix $dir_peddy/$cohort $dir_run/$cohort.vcf.gz $dir_cohort/$cohort.ped";
$r = $Syscall->run($cmd);
exit(1) if($r);

#get tsv files ready for making PCA plot with Rscript, the PCA plot made be peddy sucks
#background populations:
$cmd = qq(cat $dir_peddy/$cohort.background_pca.json | sed "s/}.{/\\n/g" | sed "s/\\[{//" | sed "s/}\\]//" | sed "s/\\"ancestry\\"://" | cut -d, -f 1-4 | sed "s/,[^:]*:/\\t/g" >$dir_peddy/$cohort.background_pca.tsv);
$r = $Syscall->run($cmd);
exit(1) if($r);
#samples:
$cmd = qq(cat $dir_peddy/$cohort.peddy.ped | tail -n +2 | cut -f 2,11-14 >$dir_peddy/$cohort.pca.tsv);
$r = $Syscall->run($cmd);
exit(1) if($r);

#run Rscript to get the PCA plot:
$cmd = "$pcaplot_bin $dir_peddy/$cohort.background_pca.tsv $dir_peddy/$cohort.pca.tsv";
$r = $Syscall->run($cmd);
exit(1) if($r);

#link in results:
#VCF no VEP annotation
modules::Utils::lns("$dir_run/$cohort.vcf.gz", "$dir_result/$cohort.vcf.gz");
modules::Utils::lns("$dir_run/$cohort.vcf.gz.tbi", "$dir_result/$cohort.vcf.gz.tbi");
#VCF with VEP annotation
modules::Utils::lns("$dir_run/$cohort.vep.vcf.gz", "$dir_result/$cohort.vep.vcf.gz");
modules::Utils::lns("$dir_run/$cohort.vep.vcf.gz.tbi", "$dir_result/$cohort.vep.vcf.gz.tbi");
#TSV report complete, all variants
modules::Utils::lns("$dir_run/$cohort.vep_all.tsv.gz", "$dir_result/$cohort.vep_all.tsv.gz");
modules::Utils::lns("$dir_run/$cohort.vep_all.tsv.gz.tbi", "$dir_result/$cohort.vep_all.tsv.gz.tbi");
#TSV report coding, only variants affecting coding sequence - exonic and splice-regions
modules::Utils::lns("$dir_run/$cohort.vep_coding.tsv.gz", "$dir_result/$cohort.vep_coding.tsv.gz");
modules::Utils::lns("$dir_run/$cohort.vep_coding.tsv.gz.tbi", "$dir_result/$cohort.vep_coding.tsv.gz.tbi");

exit(0);

END{
	warn "done script ".basename(__FILE__)."\n"
}
