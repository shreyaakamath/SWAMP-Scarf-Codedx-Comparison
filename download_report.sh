#! /bin/bash

readonly CODEDX_AUTHORIZATION="Authorization:System-Key api-key0"

function get_job_id {

    local JSON_FILE="$1"

    python -c "
import json
import sys
jobj = json.load(open('$JSON_FILE'))
print(jobj['jobId'])
"
}


function get_job_status {

    local JSON_FILE="$1"

    python -c "
import json
import sys
jobj = json.load(open('$JSON_FILE'))
print(jobj['status'])
"
}


function download {

    local HOST="$1"
    local PORT="$2"
    local REPORT_FORMAT="$3"
    local OUTFILE="$4"
    local RUN_ID="$5"

    local temp_dir=
    if test "$(uname -s)" == "Darwin"; then
	temp_dir="$(mktemp -d -t swamp-codedx)"
    else
	temp_dir="$(mktemp -d)"
    fi
    
    local http_code=
    local jobid_json="$temp_dir/jobid.json"
    
    http_code=$(curl -H "$CODEDX_AUTHORIZATION"  \
	-w '%{http_code}' \
	-X POST "http://$HOST:$PORT/codedx/api/runs/$RUN_ID/report/$REPORT_FORMAT" \
	--output "$jobid_json")

    if test $http_code -ne 200; then

	case $http_code in
	    (403) echo "Forbidden - user/key does not have generate report permission for the analysis run" ;;
	    (404) echo "Not Found - project doesn't exist or invalid report format" ;;
	    (500) echo "Internal Server Error - unexpected failure" ;;
	    (*) echo "Unknown Error" ;;
	esac
	
	exit 1;
    fi

    while true; do

	sleep 3;
	
	local jobid="$(get_job_id $jobid_json)"
	local job_status_json="$temp_dir/job_status.json"
	
	http_code=$(curl -H "$CODEDX_AUTHORIZATION"  \
	    -w '%{http_code}' \
	    -X GET "http://$HOST:$PORT/codedx/api/jobs/$jobid" \
	    --output "$job_status_json")

	if test $http_code -ne 200; then

	    case $http_code in
		(403) echo "Forbidden - user/key does not have job view permission";;
		(404) echo "Not Found - job doesn't exist or has expired" ;;
		(500) echo "Internal Server Error - unexpected failure" ;;
		(*) echo "Unknown Error" ;;
	    esac
	    
	    exit 1;
	fi

	local job_status=

	job_status="$(get_job_status $job_status_json)"

	if test "$job_status" == "completed"; then
	    break 
	elif test "$job_status" == "failed"; then
	    echo "Code Dx failed to generate report"
	    exit 1;
	fi
    done
    
    http_code=$(curl -H "$CODEDX_AUTHORIZATION"  \
	-w '%{http_code}' \
	-X GET "http://$HOST:$PORT/codedx/api/jobs/$jobid/result" \
	--output "$OUTFILE")

    if test $http_code -ne 200; then

	case $http_code in
	    (403) echo "Forbidden - user/key does not have permission to view the job result (depending on the type of job";;
	    (404) echo "Not Found - Job doesn't exist, has no result, hasn't finished yet, or has expired";;
	    (500) echo "Internal Server Error - unexpected failure" ;;
	    (*) echo "Unknown Error" ;;
	esac
	
	exit 1;
    fi

}

USAGE_STR="
Usage:
  $0 [(-p|-P|--port) <port-number>] [(-o|-O|--output) <path-to-output-file>] [(-f|-F|--format) <report-format>] <run-id>
Optional arguments:
  (-p|-P|--port) <port-number>  # Port number on local host that is forwarded to Code Dx VM. (default: 8080)
  (-o|-O|--output) <path-to-output-file> #Path to the file that report must be written to. (default: ./report.csv)
  (-f|-F|--format) <report-format> # Report format, must be one of (csv, xml). (default: csv)
Required arguments:
  <run-id> #Run ID of the analysis run
Help:
  $0 (-h|-H|--help) #To see this information again
Example:
  $0 67
  $0 --output /home/builder/tomcat-coyote---findbugs/report.csv 6
  $0 --port 5050 --output /home/builder/tomcat-coyote---findbugs/report.csv 67
  $0 --format xml --port 5050 --output /home/builder/tomcat-coyote---findbugs/report.xml 67
"

function main {
    
    local HOST="127.0.0.1"
    local PORT="8080"
    local RUN_ID=
    local REPORT_FORMAT="csv"
    local OUTFILE="$PWD/report.$REPORT_FORMAT"
    
    while test $# -gt 0; do
	local KEY="$1"

	case "$KEY" in
	    (-p|-P|--port)
	    PORT="$2"; shift ;;
	    (-o|-O|--output)
	    OUTFILE="$2"; shift ;;
	    (-f|-F|--format)
	    REPORT_FORMAT="$2"; shift ;;
	    (-h|-H|--help)
	    echo -e "$USAGE_STR"; exit 0 ;;
	    [1-9][[:digit:]]*)
		RUN_ID="$KEY" ;;
	esac
	shift;
    done

    if test -z "$RUN_ID"; then
	echo "FATAL: Missing run-id argument. run-id must be a number greater than 0";
	echo -e "$USAGE_STR"
	exit 1;
    fi

    if ! egrep --quiet '[[:digit:]]{4,5}' <(echo "$PORT"); then
	echo "FATAL: Port must be a number greater than 1024";
	exit 1;
    fi
    
    if ! egrep --quiet --ignore-case '(csv|xml)' <(echo "$REPORT_FORMAT"); then
	echo "FATAL: Report format must be csv or xml";
	exit 1;
    fi
    
    download "$HOST" "$PORT" "$REPORT_FORMAT" "$OUTFILE" "$RUN_ID"
}

main $@

