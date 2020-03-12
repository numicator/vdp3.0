package modules::Element;

use strict;
use Data::Dumper;
use modules::Definitions;
use modules::Exception;
use modules::Utils;

sub new{
	my ($class, $id, $cohort) = @_;

	my $self = bless {}, $class;
	return $self;
}

sub test{
	my($self) = shift;
	warn "Element's id is '".$self->id."'\n";
}#test

sub pipesteps{
	my($self) = shift;
	return $self->{pipestep}
}#pipesteps

sub pipestep{
	my($self, $step) = @_;
	modules::Exception->throw("Unknown step '$step' in $self\n") if(!defined $self->{pipestep}{$step});
	return $self->{pipestep}{$step}
}#pipestep

sub make_qsub{
	my($self, %args) = @_;

	my $step          = $args{step};
	my $qfile_name    = $args{qname};
	my $cohort        = $args{cohort};
	my $individual    = $args{individual};
	my $readfile      = $args{readfile};
	my $config_append = $args{config_append};
	$config_append = 0 if(!defined $config_append);
	
	my $confdir    = modules::Utils::confdir;
	my $scriptdir  = modules::Utils::scriptdir;
	my $config     = $self->config;
	my $dir_work   = $config->read("directories", "work");
	my $dir_qsub   = $config->read("directories", "qsub");
	my $dir_run    = $config->read("directories", "run");
	my $dir_result = $config->read("directories", "result");
	#my $cohort     = $config->read("cohort", "id"); #now it's passed in %args
	#my $timestamp  = TIMESTAMP;
	
	my $arg = " -config '".$config->file_name."'";	
	$arg .= " -step $step";
	$arg .= " -cohort $cohort";
	$arg .= " -individual $individual" if(defined $individual);
	$arg .= " -readfile $readfile" if(defined $readfile);	
		
	my @sstep;
	if($step =~ /^split:(.+)/){
		foreach(sort{$a <=> $b} keys %{$config->read("split")}){
			modules::Exception->throw("Can't find section '".$config->read("split", "$_")."' in config file\n") if(!defined $config->read($config->read("split", "$_")));
			push @sstep, $_;
		}
	}
	else{
		push @sstep, '';
	}
	warn "  $qfile_name\n";
	foreach(@sstep){
		#warn "Elemental: $qfile_name\n";
		my $fname = $qfile_name;
		$fname =~ s/\.split:/.$_./;
		#warn "  $fname\n";
		$fname = "$dir_work/$cohort/$dir_qsub/$fname";
		
		my($file_sfx, $arg_split);
		if($_ eq ''){
			$file_sfx  = ".";
			$arg_split = "";
		}
		else{
			$file_sfx = ".$_.";
			#$arg_split = " -split ".$config->read("split", "$_");
			$arg_split = " -split $_";
		}
		
		my $step_fs = $config->read("step:$step", "dir");
		
		open Q, ">$fname.qsub" or modules::Exception->throw("Can't open $fname.qsub for writing\n");
		
		print Q $config->read('global', "pbs_shebang")."\n";
		print Q "#PBS -P ".$config->read('global', "pbs_project")."\n";
		print Q "#PBS -q ".$config->read("step:$step", "pbs_queue")."\n";
		print Q "#PBS -l walltime=".$config->read("step:$step", "pbs_walltime").",mem=".$config->read("step:$step", "pbs_mem").",ncpus=".$config->read("step:$step", "pbs_ncpus").",jobfs=".$config->read("step:$step", "pbs_jobfs")."\n";
		print Q "#PBS -l storage=".$config->read('global', "pbs_storage")."\n";
		print Q "#PBS -l other=".$config->read('global', "pbs_other")."\n";
		print Q "#PBS -W umask=".$config->read('global', "pbs_umask")."\n";
		print Q "#PBS -o $fname.out\n";
		print Q "#PBS -e $fname.err\n\n";
		print Q "source $confdir/".$config->read('global', "env_file")."\n";
		print Q "mkdir -p $dir_work/$cohort/$dir_run/$step_fs\n";
		print Q "cd $dir_work/$cohort/$dir_run/$step_fs\n";
		print Q "echo \"pwd: \$(pwd)\" >&2\n\n";
		
		print Q "#record change in job status:\n";
		print Q "$scriptdir/pipe_status.pl --file $fname.status --status ".JOB_STARTED." --data \$PBS_JOBID\n\n";		
		print Q "#step commands to run:\n";
		if(defined $config->read("step:$step")->{modules}){
			my $modules = $config->read("step:$step")->{modules};
			$modules =~ s/[;,]/ /g;
			print Q "echo \"module load $modules\" >&2\n";
			print Q "module load $modules\n";
		}
		print Q "echo \"cmd: ".$config->read("step:$step", "cmd_1")."$arg$arg_split"."\" >&2\n";
		print Q $config->read("step:$step", "cmd_1")."$arg$arg_split\n\n";
		
		print Q "#get exit code of the command(s) (can be a pipe of several commands):\n";
		print Q "ecarray=(\${PIPESTATUS[*]})\n";
		print Q "ec=\$(IFS=+; echo \"\$((\${ecarray[*]}))\")\n";
		print Q "stat=\"".JOB_FAILED."\"\n";
		print Q "if [[ \$ec == 0 ]]; then\n";
		print Q "  stat=\"".JOB_COMPLETED."\"\n";
		print Q "fi\n";
		print Q "echo \"exit: \$stat (\${ecarray[*]}) = \$ec\" >&2\n\n";
		print Q "#record change in job status:\n";
		print Q "$scriptdir/pipe_status.pl --file $fname.status --status \$stat --data \$ec\n\n";
		print Q "#record job stats:\n";
		print Q "qstat -f \$PBS_JOBID >$fname.qstat\n\n";

		print Q "#progress the pipeline:\n";
		print Q "echo >&2\n";
		print Q "echo \"-->>-> pipe progress -->>-->\" >&2\n";
		print Q "if [[ \$ec == ".PIPE_NO_PROGRESS." ]] || [[ \$ec == ".PIPE_STOP." ]]; then\n";
		print Q "  echo \"no pipeline progress on the request of the executed tool (exit code \$ec)\" >&2\n";
		print Q "else\n";
		print Q "  $scriptdir/pipe_progress.pl -cohort $cohort -step $step$arg_split -status $fname.status\n";
		print Q "fi\n";
		close Q;
		push @{$self->{pipestep}{$step}}, "$fname.qsub";
		$self->config->file_append("$step=$fname.qsub") if($config_append);
	}
}#make_qsub

sub step_status{
	my($self, $step) = @_;
	
	my @status;
	
#	foreach(@{$self->{pipestep}{$step}}){
#		my $dir_sub = $self->config->read("cohort", "dir").'/'.$config->read("directories", "qsub");
#		my $fname = $_;
#		$fname =~ s/\.qsub/.status/;
#		$fname = "$dir_work/$cohort/$dir_qsub/$fname";
#
#	}
#	
#	my $dir_sub = $self->config->read("cohort", "dir").'/'.$config->read("directories", "qsub");
#	
#	opendir(DIR, $dir_sub) or modules::Exception->throw("Can't open cohorts directory ".$self->config->read("cohort", "dir").'/'.$config->read("directories", "qsub"));
#	while(readdir(DIR)){
#		next if(!/\.status$/);
#		push @status, $_;
#	}
#	closedir(DIR);
#

}#step_status
1

