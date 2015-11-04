#! /bin/bash
runId=0
function get_prop {
    local PROP="$1"
    local FILENAME="$2"

    echo $(egrep --only-match "$PROP[[:blank:]]*=[[:blank:]]*.+[[:blank:]]*" "$FILENAME" \
				  | sed -E "s:$PROP[[:blank:]]*=[[:blank:]]*(.+)[[:blank:]]*:\1:" )
}

function get_project_id {

	local PROJECT_NAME="$1"
	local JSON_FILE="$2"

python -c "
import json
import sys
jobj = json.load(open('$JSON_FILE'))
ids = [_d['id'] for _d in jobj['projects'] if _d['name'] == '$PROJECT_NAME']
print(ids[0] if len(ids) else '')
"
}

function get_run_id {

	local JSON_FILE="$1"
python -c "
import json
import sys
print(json.load(open('$JSON_FILE'))['runId'])
"
}

function get_new_project_id {

	local JSON_FILE="$1"
python -c "
import json
import sys
print(json.load(open('$JSON_FILE'))['id'])
"
}

#This must also be added to your browser
readonly CODEDX_AUTHORIZATION="Authorization:System-Key api-key0"

function upload {

	local HOST=$1
	local PORT=$2
	local ASSESS_DIR=$3

	local http_code=$(curl -s -H "$CODEDX_AUTHORIZATION" -w '%{http_code}' -X OPTIONS "http://$HOST:$PORT/codedx/projects/" -o /dev/null)

	test $http_code -ne 200 \
	    && echo "FATAL: Code Dx Server Not Found, curl returned error code: $http_code"  \
	    && echo "SSH tunnel may not have been setup" \
	    && exit 1;

	! test -d "$ASSESS_DIR" \
	    && echo "FATAL: '$ASSESS_DIR' is not a directory" \
	    && exit 1;
	
	if ! test -f "$ASSESS_DIR/status.out" \
			|| ! egrep --quiet -- '---(just)?parse$' <(echo "$(basename $ASSESS_DIR)"); then
	    echo "FATAL: Not a valid assessment directory '$ASSESS_DIR'"
	    echo "The assessment directory name must end with ---justparse or ---parse"
	    exit 1;
	fi

	egrep --quiet '^FAIL:[[:blank:]]+all' "$ASSESS_DIR/status.out" \
	    && echo "FATAL: Failed assessment run directory '$ASSESS_DIR'" \
	    && exit 1;

	! test -f "$ASSESS_DIR/parsed_results.conf"  \
	    && echo "FATAL: No 'parsed_results.conf' Invalid assessment directory path" \
	    && exit 1;

	local results_archive="$(get_prop parsed-results-archive $ASSESS_DIR/parsed_results.conf)"
	local results_dir="$(get_prop parsed-results-dir $ASSESS_DIR/parsed_results.conf)"
	local xml_file="$(get_prop parsed-results-file $ASSESS_DIR/parsed_results.conf)"

	local temp_dir=
	if test "$(uname -s)" == "Darwin"; then
	    temp_dir="$(mktemp -d -t swamp-codedx)"
	else
	    temp_dir="$(mktemp -d)"
	fi

	if test $? -ne 0 || test -z "$temp_dir"; then
		echo "FATAL: Could not create a temporary directory"
	fi

	tar --directory "$temp_dir" \
		-x -f "$ASSESS_DIR/$results_archive" "$results_dir/$xml_file";

	if test $? -ne 0 \
			|| ! test -f "$temp_dir/$results_dir/$xml_file"; then
	    echo "FATAL: No parsed results found in '$ASSESS_DIR/$results_archive'";
		exit 1;
	fi

	local parsed_results="$temp_dir/$results_dir/$xml_file"

	local build_dir=
	if egrep --quiet -- '---justparse$' <(echo "$(basename $ASSESS_DIR)"); then
	    local DIR_NAME="$(basename $ASSESS_DIR)"
	    build_dir="$(dirname $ASSESS_DIR)/${DIR_NAME%%---justparse}"
	else
	    build_dir="$ASSESS_DIR"
	fi

	local pkg_src_archive=
	if test -d "$build_dir" \
			&& test -f "$build_dir/build.conf"; then

	    local build_archive="$(get_prop build-archive $build_dir/build.conf)"
		
	    if test -f "$build_dir/$build_archive"; then
			tar --directory $temp_dir -x -f "$build_dir/$build_archive" "build"

			if test $? -eq 0 && test -d "$temp_dir/build"; then
				pkg_src_archive="$temp_dir/pkg_src.zip"
				(
					cd "$temp_dir/build";
					test -d "./pkg1" && cd "./pkg1";
					zip -q -r -0 $pkg_src_archive ./ 
				)
			else
				echo "WARNING: tar returned error while unarchiving 'build.tar.gz'":
			fi
		fi
	else
	    echo "WARNING: '$build_dir' not found":
	fi

	local project_name=$(sed -E 's@(.+)---(just)?parse$@\1@' <(echo "$(basename $ASSESS_DIR)"))

	local projects_json="$temp_dir/projects.json"
	
	http_code=$(curl -s -H 'Content-Type:application/json' \
					 -H "$CODEDX_AUTHORIZATION" \
					 --output "$projects_json" \
					 -w '%{http_code}' \
					 -X GET "http://$HOST:$PORT/codedx/api/projects")

	test $http_code -ne 200 \
	    && echo "FATAL: Failed to get project list from Code Dx" \
	    && exit 1;

	proj_id=$(get_project_id "$project_name" "$projects_json")

	if test $? -eq 0 && test -z "$proj_id"; then
		local new_project_json="$temp_dir/new_project.json"
	    http_code=$(curl -s -H 'Content-Type:application/json' \
						 -H "$CODEDX_AUTHORIZATION" \
						 --output "$new_project_json" \
						 --data '{"'name\":\""${project_name}"'"}' \
						 -w '%{http_code}' \
						 -X PUT "http://$HOST:$PORT/codedx/api/projects")

	    if test $http_code -ne 201; then
			echo "FATAL: Code Dx failed to create project:"
			test -f "$new_project_json" \
				&& cat "$new_project_json"
			exit 1;
	    else
			proj_id=$(get_new_project_id "$new_project_json")
	    fi
	fi

	echo curl -H "'$CODEDX_AUTHORIZATION'" \
		 -w '%{http_code}' \
		 -X POST "http://$HOST:$PORT/codedx/api/project/$proj_id/analysis" \
		 -F "file1=@$parsed_results" \
		 ${pkg_src_archive:+"-F" "file2=@$pkg_src_archive"}

    http_code=$(curl -H "$CODEDX_AUTHORIZATION" \
					 -w '%{http_code}' \
					 -X POST "http://$HOST:$PORT/codedx/api/project/$proj_id/analysis" \
					 --output "$temp_dir/analysis.json" \
					 -F "file1=@$parsed_results" \
					 ${pkg_src_archive:+"-F" "file2=@$pkg_src_archive"})
		
		temp_dir=$temp_dir"/analysis.json"
   		runId=$(get_run_id "$temp_dir")
		#echo "$runId"
	  if test $http_code -ne 202; then
		echo "FATAL: curl returned '$http_code'"
		test -f "$temp_dir/analysis.json" \
			&& cat "$temp_dir/analysis.json"
		exit 1;
    fi

}

#IFS='^J'
USAGE_STR="
Usage:
$(basename $0) [(-P|--port) <port-number>] <package>---<platform>---<tool>---(just)parse
Optional arguments:
(-P|--port) <port-number>    # Port number on local host that is forwarded to Code Dx VM
Required arguments: 
<package>---<platform>---<tool>---(just)parse   #File path to the assessment directory.
#If the assessment directory name ends with '---justparse' suffix, this script looks for an assessment directory with the name <package>---<platform>---<tool> in the same location as <package>---<platform>---<tool>---justparse. If the directory is present, source code from the file 'build.tar.gz' in the directory is extracted and uploaded along with the SCARF results.
#For assessment directory names that ends with '---parse',  the 'build.tar.gz' file is present along with the SCARF results.
Help: 
$(basename $0) (-H|--help)    #To see this information again
Example:
$(basename $0) webgoat-5.4---rhel-6.4-64---ps-jtest---parse
$(basename $0) webgoat-5.4---rhel-6.4-64---ps-jtest---justparse
$(basename $0) --port 5000 webgoat-5.4---rhel-6.4-64---ps-jtest---justparse
$(basename $0) -P 5000 webgoat-5.4---rhel-6.4-64---ps-jtest---parse
"

function main {

	local HOST="127.0.0.1"
	local PORT=
	local ASSESS_DIR=

	if test $# -eq 1; then
		if egrep --quiet "(-H|--help)" <(echo "$1"); then
			echo "$USAGE_STR" && exit 0;
		else
			PORT=8080
			ASSESS_DIR="$1"
		fi
	elif test $# -eq 3; then
		if egrep --quiet "(-p|-P|--port)" <(echo "$1"); then
			PORT="$2";
			ASSESS_DIR="$3"
		elif egrep --quiet "(-p|-P|--port)" <(echo "$2"); then
			ASSESS_DIR="$1"
			PORT="$3";
		else
			echo "$USAGE_STR" && exit 1;			
		fi
1	else
		echo "$USAGE_STR" && exit 1;
	fi
	upload $HOST $PORT $ASSESS_DIR 
	exit $runId
}

main $@
