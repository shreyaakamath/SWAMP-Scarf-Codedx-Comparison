#! /bin/bash

readonly USAGE_STR=$"
Usage:
$(basename $0) <name-for-the-vm>
"

readonly RUN_PARAMS_TEMPLATE="
SWAMP_USERNAME=<fill in a user name of your choice>
SWAMP_PASSWORD=<fill in a password of your choice>
SWAMP_USERID=<fill in a user id of your choice>
SLEEP_TIME=30"

function main {
	
	: "${1:?$USAGE_STR}"

	if egrep --quiet '^(-h|-H|--help)$' <(echo "$1"); then
		echo "$USAGE_STR"
	else
		local VM_NAME="$1"
		local CODEDX_DIR="$(dirname $(readlink -e $0))"

		if ! test -d "$CODEDX_DIR/in-files"; then
			>&2 echo "FATAL: CodeDx Directory Not Found: '$CODEDX_DIR/in-files'"
			exit 1;
		fi

		if ! test -f "$CODEDX_DIR/in-files/run-params.conf"; then
			>&2 echo "FATAL: File Not Found: '$CODEDX_DIR/in-files/run-params.conf'"
			>&2 echo "To the 'in-files' directory, add a file named 'run-params.conf' with: $RUN_PARAMS_TEMPLATE"
			exit 1;
		fi

		sudo start_vm --outsize 4000 --cpu 2 --mem 6192 \
			--name "$VM_NAME" "$CODEDX_DIR/in-files" \
			rhel-6.4-64

	fi
}

main "$@"
