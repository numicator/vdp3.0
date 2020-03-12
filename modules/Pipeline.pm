package modules::Pipeline;

use strict;
use File::Basename;
use modules::Definitions;
use modules::Exception;
use Data::Dumper;

sub new  
{
	my ($class, @args) = @_;
	my $self = bless {}, $class;
	my %args = @args;
	$self->{cohort} = $args{cohort};
	$self->{config} = $self->cohort->config;
	return $self;
}

sub config{
	my($self) = shift;
	return $self->{config};
}#config

sub cohort{
	my($self) = shift;
	return $self->{cohort};
}#cohort

sub pipesteps{
	my($self) = shift;
	return $self->{pipesteps};
}#pipesteps

sub get_pipesteps{
	my($self) = shift;

	my %steps = %{$self->config->read("steps")};
	my @steps_sort;
	#sort pipeline steps according to their config key order:
	foreach my $step(sort{my($aa) = $a=~/^(\d+):\w+/; my($bb) = $b=~/(\d+):\w+/; $aa <=> $bb} keys %steps){
		#warn "  $step\n";
		modules::Exception->throw("Config error: couldn't find section 'step:$steps{$step}'") if(!defined $self->config->read("step:$steps{$step}"));
		push @{$self->{pipesteps}}, [$step, $steps{$step}];
	}
	return $self->pipesteps;
}#get_pipesteps

sub make_qsubs{
	my($self, $config_append) = @_;
	$config_append = 0 if(!defined $config_append);
	
	warn "making qsubs for steps:\n";
	if($config_append){
		$self->config->file_append("\n#".('*'x20)." pipeline qsubs ".('*'x20));
		$self->config->file_append("[qsubs]");
		$self->config->file_append("<asarray>");
	}
	foreach my $step(@{$self->pipesteps}){
		$step->[0] =~ /^(\d+):(\w+)/;
		if($2 eq 'cohort'){
			$self->cohort->make_qsub($step->[1], $config_append)
		}
		elsif($2 eq 'individual'){
			foreach(@{$self->cohort->individual}){
				$_->make_qsub($step->[1], $config_append);
			}
		}
		elsif($2 eq 'readfile'){
			foreach(@{$self->cohort->individual}){
				$_->readfiles->make_qsub($step->[1], $config_append);
			}
		}
	}
}#make_qsubs

#sub pipe_start{
#	my($self) = shift;
#
#	my @s;
#	my $step_start;
#	foreach my $step(@{$self->pipesteps}){
#		$step->[0] =~ /^(\d+):(\w+)/;
#		last if(defined $step_start && $step_start < $1);
#		$step_start = $1;
#		
#		if($2 eq 'cohort'){
#			push @s, $self->cohort->pipestep($step->[1])
#		}
#		elsif($2 eq 'individual'){
#			foreach(@{$self->cohort->individual}){
#				push @s, $_->pipestep($step->[1]);
#			}
#		}
#		elsif($2 eq 'readfile'){
#			foreach(@{$self->cohort->individual}){
#				push @s, $_->readfiles->pipestep($step->[1]);
#			}
#		}
#	}
#	warn "submitting jobs:\n";
#	foreach my $ss(@s){
#		foreach(@{$ss}){
#			warn "  qsub $_\n";
#		}
#	}
#}#pipe_start

sub submit_step{
	my($self, $step) = @_;
	
	my $step_name = $self->config->read("steps", "$step");
	#modules::Exception->throw("Couldn't find pipeline step no. $step in the list of pipesteps") if(!defined $self->pipesteps->[$step][0])
	warn "ready to submit qsubs for step '$step=$step_name'\n";
	
	foreach my $qsub(@{$self->config->read("qsubs", "$step_name")}){
		my($status, $status_code) = $self->qsub_status($qsub);
		#warn "  w: ".basename($qsub)." $status\n";
		
		#for convinience to make regex easier:
		my $stalled = JOB_STALLED;
		my $dead    = JOB_DEAD;
		my $failed  = JOB_FAILED;
		if($status =~ /^$dead/){
			warn "  ".basename($qsub)." $status - not touching dead jobs, fix it up and clear the status file\n";
		}
		elsif($status eq JOB_UNPROCESSED || $status =~ /^$failed/ || $status =~ /^$stalled/){
			#check file lock here?
			if($status =~ /^$failed/ || $status =~ /^$stalled/){
				warn "  ".basename($qsub)." $status - resubmitting and hoping for the best\n";
			}
			else{
				warn "  ".basename($qsub)." $status - submitting\n";
			}
			my($qsub_ret, $qsub_out) = modules::Utils::pbs_qsub($qsub);
			if(!$qsub_ret){ #submission, no error
				warn "    submitted $qsub_out\n";
				$self->qsub_status_add($qsub, JOB_SUBMITTED, $qsub_out);
			}
			else{
				warn "    submision failed\n";
			}
		}
	}
}#submit_step

sub check_current_step{
	my($self, $step_current) = @_;
	#warn "***************** UNDEF $step_current ***********************\n"; undef $step_current;
	warn "provided step '$step_current'\n" if(defined $step_current);

	my $step_completed;
	my $pipe_stop_signal = 0;
	my $pipesteps = $self->pipesteps;
	
	my %qsubs; #hash of qsubs, key is order of qsub 
	foreach(keys %{$self->config->read("qsubs")}){
		my $o = $self->config->ordinal("qsubs", "$_")->[0];
		$qsubs{$o} = $_;
	}

	#going through qsubs in processing order
	foreach(sort{$a <=> $b} keys %qsubs){
		#find qsub step in the collection of pipesteps
		my $step; #index to the collection (array) of pipeline steps
		for(my $i = 0; $i < scalar @$pipesteps; $i++){
			if($pipesteps->[$i][1] eq $qsubs{$_}){
				$step = $i;
				last;
			}
		}
		modules::Exception->throw("Couldn't find pipeline step $_ in the list of pipesteps") if(!defined $step);

		#warn "checking step $qsubs{$_} (#$_): $pipesteps->[$step][0]\n";
		warn "checking step $qsubs{$_} ($pipesteps->[$step][0]): \n";
		my $qfiles = $self->config->read("qsubs", $qsubs{$_});
		my $status_step = 1;
	
		foreach(@$qfiles){
			my($status, $status_code) = $self->qsub_status($_);
			warn "  ".basename($_)." $status\t".(defined $status_code? $status_code: '')."\n";
			$pipe_stop_signal = 1 if(defined $status_code && $status_code =~ /^\d+$/ && $status_code == PIPE_STOP);
			if($status ne JOB_COMPLETED){
				$status_step = 0;
				#line below commented out to be able to see status of all qsubs from current step
				#last; #to stop looking into status of qsubs immediately after current qsub is not done
			}
		}#foreach(@$qfiles)
	
		if($pipe_stop_signal){
			warn "*** at least one of the jobs requested stop of the pipeline; check above for exit status code '".PIPE_STOP."'\n";
			$status_step = 0;
		}
		$step_completed = $step if($status_step);
		warn "step status: ".($status_step? "": "NOT ")."COMPLETED\n";
		last if(!$status_step); #to stop checking steps after current step not completed
	}#foreach(sort{$a <=> $b} keys %qsubs)

	my $step_next = -1;
	if(defined $step_completed){
		$step_next = $step_completed + 1 if($step_completed + 1 < scalar @$pipesteps);
		warn "completed step: $pipesteps->[$step_completed][0]=$pipesteps->[$step_completed][1]\n";
	}
	else{
		$step_next = 0;
		warn "no step has completed yet\n";
	}
	warn "step to run: $pipesteps->[$step_next][0]=$pipesteps->[$step_next][1]\n" if($step_next > -1);
	
	#make final adjustments to the steps:
	my($stc, $stn); #final current and next steps to report
	$stc = $pipesteps->[$step_completed][0] if(defined $step_completed);
	if($step_next == -1){
		warn "no more steps to run, pipeline finished\n";
		return($stc, $stn);
	}
	if(defined $step_current){ #we were given $step_current meaning we are being called from a finishing qsub, we should not run anything from $step_current to avoid racing
		$stn = $pipesteps->[$step_next][0] if(defined $step_completed && $step_current eq $pipesteps->[$step_completed][1]);
	}
	else{ #it's a 'general' progress - pipeline start or ocasional push - we shall run jobs from any step
		$stn = $pipesteps->[$step_next][0];
	}
	undef $stn if($pipe_stop_signal);
	warn "step '$pipesteps->[$step_next][1]' will not run.\n" if(!defined $stn);
	return($stc, $stn);
}#check_current_step

sub qsub_status{
	my($self, $qsub_file) = @_;
	
	my $status_file = $qsub_file;
	$status_file =~ s/\.qsub$/\.status/;

	return JOB_UNPROCESSED if(!-e $status_file);
	
	# ********* maybe check file lock and if locked assume still running regardless of the recorded status? **********
	
	#get newest status:
	my $status_line = `tail -n 1 $status_file`;
	chomp $status_line;
	#how many times job was already submitted:
	my $cmd = "grep \"".JOB_SUBMITTED."\" $status_file | wc -l";
	my $n_sub = `$cmd`;
	chomp $n_sub;
	$n_sub = 0 if(!defined $n_sub || $n_sub eq '');
	#how many times job was already running:
	$cmd = "grep \"".JOB_STARTED."\" $status_file | wc -l";
	my $n_run = `$cmd`;
	chomp $n_run;
	$n_run = 0 if(!defined $n_run || $n_run eq '');
	#how many times job already failed:
	$cmd = "grep \"".JOB_FAILED."\" $status_file | wc -l";
	my $n_fail = `$cmd`;
	chomp $n_fail;
	$n_fail = 0 if(!defined $n_fail || $n_fail eq '');

	#JOB_STARTED     => 'STARTED',
	#JOB_COMPLETED   => 'COMPLETED',
	#JOB_FAILED      => 'FAILED',
	#JOB_STALLED     => 'STALLED',
	#JOB_DEAD        => 'DEAD',
	#JOB_SUBMITTED   => 'SUBMITTED',
	#JOB_UNKNOWN     => 'UNKNOWN',
	my($timestamp, $status, $job_data) = split "\t", $status_line;
	$status = JOB_UNKNOWN if($status ne JOB_STARTED && $status ne JOB_COMPLETED && $status ne JOB_FAILED && $status ne JOB_STALLED && $status ne JOB_SUBMITTED);
	if($status eq JOB_FAILED){
		$status = ($n_fail <= JOB_MAX_RERUNS? JOB_FAILED: JOB_DEAD)." ($n_sub/$n_fail)"
	}
	#now we check if our 'working' job is still allive:
	elsif($status eq JOB_STARTED || $status eq JOB_SUBMITTED){
		#warn "    search for: $job_data\n";
		#foreach(keys %{$self->{qjobs}}){warn "    $_ => ".$self->qjob_status($_),"\n"}
		#if it's alive, its jobid should be in the job queue hash:
		if($self->qjob_status($job_data) == QJOB_NOTFOUND){
			#as the job is not allive anymore, we check how many times it was already submitted and run, and either we give it another chance (STALLED) or proclaim it dead
			$status = ($n_run <= JOB_MAX_RERUNS && $n_sub <= JOB_MAX_RESUB? JOB_STALLED: JOB_DEAD)." ($n_sub/$n_run)";
		}
		#warn "    status: $status\n";
	}
	return($status, $job_data);
}#qsub_status

sub qsub_status_add{
	my($self, $qsub_file, $status, $code) = @_;
	$code = '' if(!defined $code);
		
	my $status_file = $qsub_file;
	$status_file =~ s/\.qsub$/\.status/;

	my $oh;
	open($oh, ">>", $status_file) or modules::Exception->throw("Can't open status file '$status_file' for writing");
	$oh->autoflush(1);
	print $oh "".modules::Utils::get_time_stamp()."\t$status\t$code\n";
	close $oh;
}#qsub_status_add

sub qjob_status{
	my($self, $jobid) = @_;
	#warn"    qjob_status for job $jobid = ".$self->qjobs($jobid)."\n";
	return QJOB_NOTFOUND if(!defined $self->qjobs($jobid));
	return $self->qjobs($jobid);
}#qjob_status

sub qjobs{
	my($self, $jobid) = @_;
	return $self->{qjobs}{$jobid};
}#qjobs

sub get_qjobs{
	my($self) = shift;
	my $h = modules::Utils::pbs_qjobs();
	#decode job status code into Pipeline QJOB_ code constants:
	foreach(keys %{$h}){
		my $c;
		if($h->{$_} eq 'R'){
			$c = QJOB_RUNNING;
		}
		elsif($h->{$_} eq 'Q'){
			$c = QJOB_QUEUED;
		}
		elsif($h->{$_} eq 'W'){
			$c = QJOB_WAITING;
		}
		elsif($h->{$_} eq 'Q' || $h->{$_} eq 'E'){
			$c = QJOB_RUNNING;
		}
		elsif($h->{$_} eq 'F'){
			$c = QJOB_FINISHED;
		}
		elsif($h->{$_} eq 'H'){
			$c = QJOB_ONHOLD;
		}
		else{
			modules::Exception->warning("unknown job status code 'h->{$_}' for job '$_'")
		}
		$self->{qjobs}{$_} = $c;
	}
}

1