#!/bin/bash -x
source dss_common.sh

# The list of services available to the system
SERVICE_FILE=services.txt

# This is the info on our service and provider
PROVIDER_NAME=picsl

# Create a temporary directory for this process
if [[ ! $TMPDIR ]]; then
  TMPDIR=$(mktemp -d /tmp/ashs_daemon.XXXXXX) || exit 1
fi

# What to do when the script is killed
kill_script()
{
  if [[ -v TICKET_ID && $TICKET_ID -gt 0 ]]; then
    fail_ticket $TICKET_ID "Pipeline received interrupt signal"
    exit -1
  else
    exit 1
  fi
}

# Set the trap
trap kill_script SIGINT SIGTERM

# This is the main function that gets executed. Execution is very simple,
#   1. Claim a ticket under one of the available services
#   2. If no ticket claimed, sleep return to 1
#   3. Extract necessary objects from the ticket
#   4. Run ASHS
function main_loop()
{
  # The code associated with the current service
  process_code=${1?}

  # The working directory
  workdir=${2?}

  while [[ true ]]; do

    # If a file has been created in the script directory called .dss_abort, then we should 
    # abort what we are doing and not listen to more input
    if [[ -f $SCRIPTDIR/.dss_abort ]]; then
      echo "File .dss_abort present - exiting main loop"
      exit 0
    fi

    # Try to claim for the ASHS service
    SERVICE_CSV=$(echo $(cat $SERVICE_FILE | awk '{print $1}') | sed -e "s/ /,/g")
    itksnap-wt -P -dssp-services-claim $SERVICE_CSV $PROVIDER_NAME $process_code | tee $TMPDIR/claim.txt

    # If negative result, sleep and continue
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
      sleep 15
      continue
    fi

    # Get the ticket ID as the last line of output
    TICKET_ID=$(cat $TMPDIR/claim.txt | tail -n 1 | awk '{print $1}')
    SERVICE=$(cat $TMPDIR/claim.txt | tail -n 1 | awk '{print $2}')

    # Set the work directory for this ticket
    WORKDIR=$workdir/$(printf ticket_%08d $TICKET_ID)

    # Download the files associated with this ticket
    itksnap-wt -P -dssp-tickets-download $TICKET_ID $WORKDIR > $TMPDIR/download.txt

    # If the download failed we mark the ticket as failed
    if [[ $? -ne 0 ]]; then
      fail_ticket $TICKET_ID "Failed to download the ticket after 1 attempts"
      continue
    fi

    # Get the workspace filename - this will be the last file downloaded
    WSFILE=$(cat $TMPDIR/download.txt | grep "\.itksnap$") 

    # Call the appropriate script
    SCRIPT=$(cat $SERVICE_FILE | grep "^${SERVICE}" | awk '{print $2}')
    WSRESULT=$WORKDIR/$(printf %08d $TICKET_ID)_results.itksnap

    # Export PATH and other important stuff
    export PATH TMPDIR
    export -f fail_ticket dereflink

    # Call with parameters: ticket, workdir, input workspace, output workspace
    bash $SCRIPT ${TICKET_ID} ${WORKDIR} ${WSFILE} $WSRESULT

    # If script failed, we continue, but do not call fail ticket because it should
    # already be failed
    if [[ $? -ne 0 ]]; then
      fail_ticket_if_not_failed $TICKET_ID "Unknown error encountered by analysis pipeline"
      continue
    fi

    # Upload the result workspace
    itksnap-wt -i $WSRESULT -dssp-tickets-upload $TICKET_ID

    # If the download failed we mark the ticket as failed
    if [[ $? -ne 0 ]]; then
      fail_ticket $TICKET_ID "Failed to upload the ticket"
      continue
    fi

    # Set the status of the ticket to success
    itksnap-wt -dssp-tickets-success $TICKET_ID

    # We no longer have an active ticket
    unset TICKET_ID

  done
}

# -------------------------
# Main Entrypoint of Script
# -------------------------
if [[ $# -ne 2 ]]; then
  echo "Usage: dss_daemon.sh service_desc workdir"
  exit
fi

main_loop "$@"
