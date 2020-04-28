#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
	DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
	SOURCE="$( readlink "$SOURCE" )"
	[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
echo "codebase: $DIR"

OPTS=`getopt -o a --long published:: -n "$0" -- "$@"`
#echo "arguments: $OPTS"

if [ $? != 0 ]; then 
	echo "failed parsing arguments, check names of the passed arguments." >&2; 
	exit 1;
fi

eval set -- "$OPTS"

while true; do
	case "$1" in
		--published)
			SUBMIT="--published"
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

source $DIR/conf/environment.txt
$DIR/scripts/pipe_get_to_publish.pl $SUBMIT

if [ $? != 0 ]; then
	echo "ERROR: something went wrong in pipe_get_to_publish.pl script"
	exit 1
else
	echo "All done"
fi
