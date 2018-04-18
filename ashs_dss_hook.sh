#!/bin/bash

########################################################
# COMMON ASHS HOOK SCRIPT FOR ALL ASHS-based SERVICES
# ---
#
# This script can be passed either:
# - a single ticket id in $ASHS_HOOK_DATA
# - a compound string with comma-separated fielnds in $ASHS_HOOK_DATA
#    ticket_id sub_task_prefix,subtask_pstart,subtask_ptotal
########################################################

# Set PATH to the workspace tool
PATH=$HOME/bin:$PATH

# Check whether the HOOK data is in regular or compound formar
if [[ $(echo $ASHS_HOOK_DATA | cut -d, -s -f 1) ]]; then
  ticket_id=$(echo $ASHS_HOOK_DATA | cut -d, -s -f 1)
  prefix="$(echo $ASHS_HOOK_DATA | cut -d, -s -f 2) "
  subtask_pstart=$(echo $ASHS_HOOK_DATA | cut -d, -s -f 3)
  subtask_ptotal=$(echo $ASHS_HOOK_DATA | cut -d, -s -f 4)
else
  ticket_id=$ASHS_HOOK_DATA
  subtask_pstart=0.0
  subtask_ptotal=1.0
fi

# Check that the ticket is still in 'claimed' state
status=$(itksnap-wt -P -dssp-tickets-status $ticket_id)
if [[ $? -eq 0 && $status != 'claimed' ]]; then
  echo "Ticket status has changed on the server - aborting"
  exit 255
fi

# Simple case statement to split 
case "${1?}" in 
  progress)
    p0=$(echo ${2?} $subtask_pstart $subtask_ptotal | awk '{print $2 + $1 * $3}')
    p1=$(echo ${3?} $subtask_pstart $subtask_ptotal | awk '{print $2 + $1 * $3}')
    itksnap-wt -dssp-tickets-set-progress $ticket_id $p0 $p1 ${4?}
    ;;
  info|warning|error)
    itksnap-wt -dssp-tickets-log $ticket_id ${1?} "${prefix}${2?}"
    ;;
  attach)
    itksnap-wt -dssp-tickets-attach $ticket_id "${prefix}${2?}" "${3?}"
    ;;
esac
