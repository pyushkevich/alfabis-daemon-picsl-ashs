#!/bin/bash

# Set up SGE
source /opt/sge/ashs/common/settings.sh

# Add path to itksnap-wt
PATH=$HOME/bin:$PATH

# Dereference a link - different calls on different systems
function dereflink ()
{
  if [[ $(uname) == "Darwin" ]]; then
    greadlink -f $1
  else
    readlink -f $1
  fi
}

# This function sends an error message to the server
function fail_ticket()
{
  local ticket_id=${1?}
  local message=${2?}

  itksnap-wt -dssp-tickets-fail $ticket_id "$message"
  sleep 2
}

# Define the script home directory
SCRIPTDIR=$(dirname $(dereflink $0))
