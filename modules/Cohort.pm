package modules::Cohort;
use base modules::Element;

use strict;
use File::Path qw(make_path remove_tree);
use File::Basename;
use File::Copy qw(cp);
use modules::Definitions;
use modules::Exception;
use modules::Individual;
use modules::SystemCall;
use Data::Dumper;

sub new{
	my($class, $id, $config, $ped, $fqfiles) = @_;
	my $self = bless {}, $class;
	$self->{id}     = $id;
	$self->{config} = $config;
	$self->{ped}    = $ped;
	$self->{fqfiles}  = $fqfiles;
	return $self;
}

sub id{
	my($self) = shift;
	return $self->{id};
}#id

sub ped{
	my($self) = shift;
	return $self->{ped};
}#ped

sub individual{
	my($self) = shift;
	return $self->{individual};
}#individual

sub config{
	my($self) = shift;
	return $self->{config};
}#config

sub pipesteps{
	my($self) = shift;
	return $self->{pipesteps};
}#pipesteps

sub workdir{
	my($self) = shift;
	return $self->config->read("directories", "work").'/'.$self->id
}#workdir

sub has_completed{
	my($self) = shift;
	my $r = 0;
	my $file = $self->workdir.'/'.$self->id.'.done';
	$r = 1 if(-s $file);
	return $r;
}#has_completed

sub set_completed{
	my($self) = shift;
	my $file  = $self->workdir.'/'.$self->id.'.done';
	my $ts    = modules::Utils::get_time_stamp;
	open O, ">$file" or modules::Exception->throw("Can't open $file for writing\n");
	print O $ts;
	close O;
	warn 'cohort '.$self->id." set complete marker file\n";
}#set_completed

sub reset_completed{
	my($self) = shift;
	my $file  = $self->workdir.'/'.$self->id.'.done';
	unlink($file) or modules::Exception->throw("Can't unlink $file\n");
	warn 'cohort '.$self->id." reset complete marker file\n";
}#reset_completed

sub has_notready_fastq{
	my($self) = shift;
	my $r = 0;
	my $file = $self->workdir.'/'.$self->id.'.fastq_notready';
	$r = 1 if(-s $file);
	return $r;
}#has_notready_fastq

sub set_notready_fastq{
	my($self) = shift;
	my $file  = $self->workdir.'/'.$self->id.'.fastq_notready';
	my $ts    = modules::Utils::get_time_stamp;
	open O, ">$file" or modules::Exception->throw("Can't open $file for writing\n");
	print O $ts;
	close O;
	warn 'cohort '.$self->id." set fastq_notready marker file\n";
}#set_notready_fastq

sub reset_notready_fastq{
	my($self) = shift;
	my $file  = $self->workdir.'/'.$self->id.'.fastq_notready';
	unlink($file) or modules::Exception->throw("Can't unlink $file\n");
	warn 'cohort '.$self->id." reset fastq_notready marker file\n";
}#reset_notready_fastq

sub make_workdir{
	my($self, $overwrite, $cp_qsub) = @_;
	
	my $cohort     = $self->id;
	my $config     = $self->config;
	my $dir_work   = $config->read("directories", "work");
	my $dir_qsub   = $config->read("directories", "qsub");
	my $dir_run    = $config->read("directories", "run");
	my $dir_reads  = $config->read("directories", "reads");
	my $dir_tmp    = $config->read("directories", "tmp");
	my $dir_result = $config->read("directories", "result");

	if(-d "$dir_work/$cohort"){
		#if($overwrite){
		#	warn "removing existing working directory '$dir_work/$cohort'\n";
		#	remove_tree("$dir_work/$cohort");
		#}
		if($overwrite){
			warn "clearning directory:\n";
			opendir(DIR, "$dir_work/$cohort") or modules::Exception->throw("Can't open reads directory $dir_work/$cohort");
			while(readdir(DIR)){
				next if(!(/^$dir_qsub$/ || /^$dir_run$/ || /^$dir_result$/));
				warn "  $dir_work/$cohort/$_\n";
				remove_tree("$dir_work/$cohort/$_");
			}
			closedir(DIR);
		}
		else{
			warn "working directory '$dir_work/$cohort' already exists; it will NOT be cleared\n";
		}
	}
	#if(-d "$dir_work/$cohort"){
	#	modules::Exception->throw("working directory '$dir_work/$cohort' already exists, use -overwrite to proceed") if(!$overwrite);
	#	warn "removing existing working directory '$dir_work/$cohort'\n";
	#	remove_tree("$dir_work/$cohort");
	#}
	my $username = modules::Utils::username;
	my $tstamp = modules::Utils::get_time_stamp;
	make_path("$dir_work/$cohort/$dir_qsub");
	make_path("$dir_work/$cohort/$dir_run");
	make_path("$dir_work/$cohort/$dir_run/$dir_tmp");
	make_path("$dir_work/$cohort/$dir_result");
	
	#imiedietly mark cohort as not ready for porcessing:
	$self->set_notready_fastq;
	
	#directiry structure for reads
	make_path("$dir_work/$cohort/$dir_reads");
	foreach my $indv(keys %{$self->ped->ped->{$self->id}}){
		make_path("$dir_work/$cohort/$dir_reads/$indv");
	}

	#copy config file
	my($cfn, $cdir) = fileparse($config->file_name);
	cp($config->file_name, "$dir_work/$cohort/$cfn") or modules::Exception->throw($!);
	$config->reload("$dir_work/$cohort/$cfn");
	$self->config->file_append("\n#".('*'x20)." Cohort $cohort configuration ".('*'x20));
	$self->config->file_append("[cohort]");
	$self->config->file_append("id=$cohort\ndir=$dir_work/$cohort\nusername=$username\ntime_start=$tstamp");
	$config->reload("$dir_work/$cohort/$cfn");
	
	#copy PEDX file and make regular PED file:
	($cfn, $cdir) = fileparse($self->ped->file_name);
	if($self->ped->file_name ne "$dir_work/$cohort/$cfn"){
		cp($self->ped->file_name, "$dir_work/$cohort/$cfn") or modules::Exception->throw($!);
		chmod 0660, "$dir_work/$cohort/$cfn" or modules::Exception->throw($!);
		$self->ped->reload("$dir_work/$cohort/$cfn");
		modules::Exception->throw("the cohort extended PED file has to have '.pedx' extension") if($cfn !~ /\.pedx$/);
		$cfn =~ s/\.pedx/\.ped/;
		open O, ">$dir_work/$cohort/$cfn" or modules::Exception->throw("Can't open: '$dir_work/$cohort/$cfn' for writing");
		print O $self->ped->ped_string;
		close O;
	}
	
	#copy read files from their original loacation (from Vardb object) to cohort work location
	if($cp_qsub){
		($cfn, $cdir) = fileparse($self->ped->file_name);
		$cfn =~ s/\.pedx/\.cp-fastq/;
		warn "copy of the fastq files and finishing of the cohort setup will be performed by a qsub job $cfn.qsub\n";
		
		open Q, ">$dir_work/$cohort/$cfn.qsub" or modules::Exception->throw("Can't open: '$dir_work/$cohort/$cfn.qsub' for writing");
		print Q $self->config->read('global', "pbs_shebang")."\n";
		print Q "#PBS -P ".$self->config->read('global', "pbs_project")."\n";
		print Q "#PBS -q ".$self->config->read("cp_fastq", "pbs_queue")."\n";
		print Q "#PBS -l walltime=".$self->config->read("cp_fastq", "pbs_walltime").",mem=".$self->config->read("cp_fastq", "pbs_mem").",ncpus=".$self->config->read("cp_fastq", "pbs_ncpus")."\n";
		print Q "#PBS -l storage=".$self->config->read('global', "pbs_storage")."\n";
		print Q "#PBS -l other=".$self->config->read('global', "pbs_other")."\n";
		print Q "#PBS -W umask=".$self->config->read('global', "pbs_umask")."\n";
		print Q "#PBS -o $dir_work/$cohort/$cfn.out\n";
		print Q "#PBS -e $dir_work/$cohort/$cfn.err\n\n";
		#print Q "#PBS -e exit\n\n";
	}
	else{
		warn "copy of the fastq files will be performed immediately without invoking a qsub job\n";
	}
	foreach my $smpl(keys %{$self->{fqfiles}}){
		warn "  $smpl - copying fastq files\n";
		foreach(@{$self->{fqfiles}->{$smpl}}){
			warn "    ".basename($_->[0]). " ".basename($_->[1])."\n";
			if($overwrite || !-s "$dir_work/$cohort/$dir_reads/$smpl/".basename($_->[0])){
				if($cp_qsub){
					print Q "echo cp -n $_->[0] $dir_work/$cohort/$dir_reads/$smpl/".basename($_->[0])." >&2\n";
					print Q "cp -n $_->[0] $dir_work/$cohort/$dir_reads/$smpl/".basename($_->[0])."\n";
					print Q "echo chmod 0660 $dir_work/$cohort/$dir_reads/$smpl/".basename($_->[0])." >&2\n";
					print Q "chmod 0660 $dir_work/$cohort/$dir_reads/$smpl/".basename($_->[0])."\n";
				}
				else{
					cp($_->[0], "$dir_work/$cohort/$dir_reads/$smpl/".basename($_->[0])) or modules::Exception->throw("$dir_work/$cohort/$dir_reads/$smpl/".basename($_->[0])." $!");
					chmod 0660, "$dir_work/$cohort/$dir_reads/$smpl/".basename($_->[0]) or modules::Exception->throw("$dir_work/$cohort/$dir_reads/$smpl/".basename($_->[0])." $!");
				}
			}
			else{
				warn "    NOT overwriting existing file $dir_work/$cohort/$dir_reads/$smpl/".basename($_->[0])."\n";
			}
			if($overwrite || !-s "$dir_work/$cohort/$dir_reads/$smpl/".basename($_->[1])){
				if($cp_qsub){
					print Q "echo cp -n $_->[1] $dir_work/$cohort/$dir_reads/$smpl/".basename($_->[1])." >&2\n";
					print Q "cp -n $_->[1] $dir_work/$cohort/$dir_reads/$smpl/".basename($_->[1])."\n";
					print Q "echo chmod 0660 $dir_work/$cohort/$dir_reads/$smpl/".basename($_->[1])." >&2\n";
					print Q "chmod 0660 $dir_work/$cohort/$dir_reads/$smpl/".basename($_->[1])."\n\n";
				}
				else{
					cp($_->[1], "$dir_work/$cohort/$dir_reads/$smpl/".basename($_->[1])) or modules::Exception->throw("$dir_work/$cohort/$dir_reads/$smpl/".basename($_->[1])." $!");
					chmod 0660, "$dir_work/$cohort/$dir_reads/$smpl/".basename($_->[1]) or modules::Exception->throw("$dir_work/$cohort/$dir_reads/$smpl/".basename($_->[1])." $!");
				}
			}
			else{
				warn "    NOT overwriting existing file $dir_work/$cohort/$dir_reads/$smpl/".basename($_->[1])."\n";
			}
		}
	}#foreach my $smpl(keys %{$self->{fqfiles}})
	if($cp_qsub){
		print Q "echo rm -vf $dir_work/$cohort/$cohort.fastq_notready >&2\n";
		print Q "rm -vf $dir_work/$cohort/$cohort.fastq_notready >&2\n";
		#print Q "ls -l $dir_work/$cohort/$cohort.fastq_notready\n";
		print Q "echo copy of fastq files done >&2\n\n";
		print Q "echo finishing cohort setup and starting the pipeline: >&2\n";
		print Q "source ".modules::Utils::confdir."/".$self->config->read('global', "env_file")."\n";
		print Q modules::Utils::scriptdir."/pipe_add_cohort.pl --cohort $cohort --submit\n";
		close Q;
		my $r = system("qsub $dir_work/$cohort/$cfn.qsub >/dev/null");
		if($r){
			modules::Exception->throw("qsub $dir_work/$cohort/$cfn.qsub failed");
		}
		else{
			warn "  qsub submitted job '$cfn.qsub' to copy the fastq files and start the pipeline\n";
		}
	}
	else{
		$self->reset_notready_fastq;
	}
}#make_workdir

sub load_ped{
	my($self, $ped) = @_;
	$self->{ped} = $ped;	
}#load_ped

sub add_individual{
	my($self, $id) = @_;
	my $i = modules::Individual->new($id, $self);
	push @{$self->{individual}}, $i;
	$i->get_readfiles();
}#add_individual

sub config_add_readfiles{
	my($self) = shift;
	
	$self->config->file_append("\n#".('*'x20)." fastq read files ".('*'x20));
	foreach my $indv(@{$self->individual}){
		$indv->config_add_readfiles;
	}
	$self->config->reload();
}#config_add_readfiles

sub add_individuals_ped{
	my($self, $overwrite) = @_;
	
	foreach my $indv(keys %{$self->ped->ped->{$self->id}}){
		#warn "$indv\n";
		$self->add_individual($indv);
		#$self->ped->ped->{$self->id}{$indv}{capturekit}
		#$self->config->file_append("id=$cohort\ndir=$dir_work/$cohort");
	}
}#add_individuals_ped

#sub get_pipesteps{
#	my($self) = shift;
#
#	my %steps = %{$self->config->read("steps")};
#	my @steps_sort;
#	#sort pipeline steps according to their config key order:
#	foreach my $step(sort{my($aa) = $a=~/^(\d+):\w+/; my($bb) = $b=~/(\d+):\w+/; $aa <=> $bb} keys %steps){
#		warn "  $step\n";
#		push @{$self->{pipesteps}}, [$step, $steps{$step}];
#	}
#	return $self->pipesteps;
#}#get_pipesteps

sub make_qsub{
	my($self, $step, $config_append) = @_;

	my $qname = $self->id.".$step";
	#$self->SUPER::make_qsub($step, $qname);
	$self->SUPER::make_qsub(step => $step, qname => $qname, cohort => $self->id, config_append => $config_append);
}#make_qsub

1
