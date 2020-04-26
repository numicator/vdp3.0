#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
	DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
	SOURCE="$( readlink "$SOURCE" )"
	[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
echo "codebase: $DIR"

OPTS=`getopt -o a --long cohort:,unpublish:: -n "$0" -- "$@"`
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
		--unpublish)
			SUBMIT="--unpublish"
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
	echo "ERROR: Specify cohort id with argument --cohort <cohort_id>, use --cohort --unpublish to remove the publication record"
	exit
fi

if [ -z "$SUBMIT" ]; then 
	echo "INFO: Cohort $COHORT will be published"
else
	echo "INFO: Cohort $COHORT will be unpublished"
fi
COHORT="--cohort $COHORT"

source $DIR/conf/environment.txt
$DIR/scripts/pipe_publish_cohort.pl $COHORT $SUBMIT

if [ $? != 0 ]; then
	echo "ERROR: something went wrong in pipe_publish_cohort.pl script"
	exit 1
else
	echo "All done"
fi
