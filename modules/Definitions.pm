package modules::Definitions;

use strict;
require Exporter;

my %constants;

BEGIN{
	%constants = (
		JOB_UNPROCESSED => 'UNPROCESSED',
		JOB_STARTED     => 'STARTED',
		JOB_DONE        => 'DONE',
		JOB_COMPLETED   => 'COMPLETED',
		JOB_FAILED      => 'FAILED',
		JOB_STALLED     => 'STALLED',
		JOB_DEAD        => 'DEAD',
		JOB_SUBMITTED   => 'SUBMITTED',
		JOB_UNKNOWN     => 'UNKNOWN',

		QJOB_NOTFOUND => 0,
		QJOB_RUNNING  => 1,
		QJOB_QUEUED   => 2,
		QJOB_WAITING  => 3,
		QJOB_FINISHED => 4,
		QJOB_ONHOLD   => 5,
		QJOB_NOSTATUS => 99,

		JOB_MAX_RERUNS => 2,
		JOB_MAX_RESUB  => 8,
		
		PIPE_STOP        => 88,
		PIPE_NO_PROGRESS => 66,
		
		COHORT_RUN_START => 'START',
		COHORT_RUN_DONE  => 'DONE',
		
		TIMESTAMP => '%d-%m-%Y_%H:%M:%S'
	);
}

use constant \%constants;

our @ISA    = qw(Exporter);
our @EXPORT = (keys %constants);

1
