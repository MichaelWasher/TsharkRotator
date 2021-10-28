#!/bin/bash
# Configurations
NAME=target-pod
NAMESPACE=default
ERROR_MESSAGE=failed

KILL_DELAY=30
OUTPUT_DIR=/host/tmp/output

# Collect Pod details
POD_ID=$(chroot /host crictl pods --namespace ${NAMESPACE} --name ${NAME} -q)
CONT_ID=$(chroot /host bash -c "crictl ps --pod $POD_ID -q")
CONT_PID=$(chroot /host bash -c "runc state $CONT_ID | jq .pid")
LOG_PATH=$(chroot /host crictl inspect $CONT_ID | jq -r .status.logPath)

# Start tcpdump
function start_tcpdump(){
    # collect 100MB of rotating PCAPs
    echo "Starting the tshark collection"
    nsenter -n -t $CONT_PID -- tshark -a filesize:10000 -b files:10 -i any -w $OUTPUT_DIR &
    KILL_PID=$!
}


# Kill a PID when a file is present after a certain delay
function kill_on_error(){
    # Tail the logs of the container until the error is seen and create the triggerfile
    echo "Tailing the logs located at '${LOG_PATH}' waiting for an occurance of '${ERROR_MESSAGE}'"
    tail -f /host/$LOG_PATH | sed "/${ERROR_MESSAGE}/ q"

    echo "The issue has been spotted in the provided logs. Will wait ${KILL_DELAY} seconds before halting collection."
    for i in {0..$KILL_DELAY..1}; do 
        echo -e "${i}/${KILL_DELAY}"
        sleep 1
    done
	
    sleep $KILL_DELAY
	kill $KILL_PID
    echo "Killed process: ${KILL_PID}"
}

# Start pcap collection in background
start_tcpdump

# Start kill_on_error in background
kill_on_error 
