#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
	DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
	SOURCE="$( readlink "$SOURCE" )"
	[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
echo "codebase: $DIR"

OPTS=`getopt -o a --long input:,project:,submit:: -n "$0" -- "$@"`
#echo "arguments: $OPTS"

if [ $? != 0 ]; then 
	echo "failed parsing arguments, check names of the passed arguments." >&2; 
	exit 1;
fi

eval set -- "$OPTS"

while true; do
	case "$1" in
		--input)
			INPUT=$2
			shift 2
			;;
		--project)
			PRJ=$2
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

if [ -z "$INPUT" ]; then 
	echo "ERROR: Specify name of input tsv file with argument --input <filename.tsv>"
	exit
fi
if [ -z "$PRJ" ]; then 
	echo "ERROR: Specify name of the project with argument --project <project>"
	exit
fi
if [ -z "$SUBMIT" ]; then 
	echo "INFO: This is onlt a 'dry run', to perform the actuall actions specify argument --submit"
	SUBMIT="--dryrun"
else
	read -p "Warning: You have specified argument --submit. Should the pipeline be started? (yes/NO): " USRINPUT
	if [[ $(tr "[:upper:]" "[:lower:]" <<<"$USRINPUT") = "yes" ]]; then
		echo "answer ($USRINPUT) was positive, continuing"
	else
		echo "answer ($USRINPUT) was negative, stopping now"
		exit
	fi
fi

source $DIR/conf/environment.txt
$DIR/scripts/pipe_add_cohort.pl --data_file $INPUT --project $PRJ $SUBMIT

if [ $? != 0 ]; then
	echo "ERROR: something went wrong in pipe_add_cohort.pl script"
	exit 1
else
	echo "All done"
fi
