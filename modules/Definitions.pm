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

		JOB_MAX_RERUNS => 6,    #max numbers of step runs (executions) before step is considered dead
		JOB_MAX_RESUB  => 10,   #max numbers of step submissions before step is considered dead
		
		PIPE_STOP        => 88, #error code recognized as request to stop the pipeline
		PIPE_NO_PROGRESS => 66, #error code recognized as request to not progress the pipeline
		
		LOCK_MAX_AGE     => 600, #max age of lock file in seconds before lock file considered 'stale' and the lock can be overrided
		
		COHORT_RUN_INIT        => 'INIT',         #log entry in the the pipeline db
		COHORT_RUN_START       => 'START',        #log entry in the the pipeline db
		COHORT_RUN_DONE        => 'DONE',         #log entry in the the pipeline db
		COHORT_RUN_DONE_PUBLIC => 'DONE_PUBLIC',  #log entry in the the pipeline db
		COHORT_RUN_PUBLISHED   => 'PUBLISHED',    #log entry in the the pipeline db
		
		TIMESTAMP => '%d-%m-%Y_%H:%M:%S' #time stamp format in all pipeline loging
	);
}

use constant \%constants;

our @ISA    = qw(Exporter);
our @EXPORT = (keys %constants);

1
