#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
	DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
	SOURCE="$( readlink "$SOURCE" )"
	[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
echo "codebase: $DIR"

OPTS=`getopt -o a --long cohort:,submit:: -n "$0" -- "$@"`
#echo "arguments: $OPTS"

if [ $? != 0 ]; then 
	echo "failed parsing arguments, check names of the passed arguments." >&2; 
	exit 1;
fi

eval set -- "$OPTS"

while true; do
	case "$1" in
		--cohort)
			COHORT=$2
			shift 2
			;;
		--submit)
			SUBMIT="--qsub_copy"
			shift 2
			;;
		--)
			shift
			break
			;;
		*)
			echo "error when processing the arguments - unknow argument '$1'"
			exit 1
			;;
	esac
done

if [ -z "$COHORT" ]; then 
	echo "ERROR: Specify cohort id with argument --cohort <cohort_id>"
	exit
fi
if [ -z "$SUBMIT" ]; then 
	echo "INFO: Cohort $COHORT will not be progressed through the pipeline, to submit next unprocessed job(s) use argument --submit"
	SUBMIT="--no_submit"
else
	echo "INFO: Cohort $COHORT will submit next uprocessed job(s)"
	SUBMIT=""
fi

source $DIR/conf/environment.txt
$DIR/scripts/pipe_progress.pl --cohort $COHORT $SUBMIT

if [ $? != 0 ]; then
	echo "ERROR: something went wrong in pipe_progress.pl script"
	exit 1
else
	echo "All done"
fi
