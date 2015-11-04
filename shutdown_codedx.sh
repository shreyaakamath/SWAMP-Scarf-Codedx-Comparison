#! /bin/bash

readonly USAGE_STR="
Usage:
$0 <name-for-the-vm>
"

function main { 

	: ${1:?$USAGE_STR}

    readonly VMNAME="$1"
    
	local VMSTATE=
	VMSTATE=$(sudo virsh domstate --domain "$VMNAME")
	
	test $? -ne 0 \
		&& echo "To check if the VM exists, on the terminal, run 'sudo virsh list' OR 'sudo virsh list --all'" \
		&& exit 1;

	if test "$VMSTATE" == "running" -o "$VMSTATE" == "shut off"; then 
		sudo virsh destroy "$VMNAME"
		sudo vm_cleanup "$VMNAME"
	else
		echo "Unknown VM state: $VMSTATE"
	fi
}

main $@
