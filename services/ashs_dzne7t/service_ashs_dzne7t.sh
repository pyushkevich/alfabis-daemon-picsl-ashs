#!/bin/bash
source dss_common.sh

# Set the path to ASHS
export ASHS_ROOT=/home/ashs/tk/ashs-fast
ASHS_ATLAS=/home/ashs/tk/ashs_atlas_dzne7t

# Get the command-line arguments
TICKET_ID=${1?}
WORKDIR=${2?}
WSFILE=${3?}
WSRESULT=${4?}

# Identify the T1 and the T2 images
T1_FILE=$(itksnap-wt -P -i $WSFILE -llf T1-MRI)
if [[ $(echo $T1_FILE | wc -w) -ne 1 || ! -f $T1_FILE ]]; then
  fail_ticket $TICKET_ID "Missing tag 'T1-MRI' in ticket workspace"
  exit -1
fi

T2_FILE=$(itksnap-wt -P -i $WSFILE -llf T2-MRI)
if [[ $(echo $T2_FILE | wc -w) -ne 1 || ! -f $T2_FILE ]]; then
  fail_ticket $TICKET_ID "Missing tag 'T2-MRI' in ticket workspace"
  exit -1
fi

# Provide callback info for ASHS to update progress and send log messages
export ASHS_HOOK_SCRIPT=$PWD/ashs_dss_hook.sh
export ASHS_HOOK_DATA=$TICKET_ID

# For qsub fine-tuning
ASHS_QSUB_SCRIPT=$SCRIPTDIR/ashs_qsub_opts.sh

# The 8-digit ticket id string
IDSTRING=$(printf %08d $TICKET_ID)

# Ready to roll!
$ASHS_ROOT/bin/ashs_main.sh \
  -a $ASHS_ATLAS \
  -g $T1_FILE -f $T2_FILE \
  -w $WORKDIR/ashs \
  -I $IDSTRING \
  -H -Q -z $ASHS_QSUB_SCRIPT

# Check the error code
if [[ $? -ne 0 ]]; then
  # TODO: we need to supply some debugging information, this is not enough
  # ASHS crashed - report the error
  fail_ticket $TICKET_ID "ASHS execution failed"
  exit -1 
fi

# TODO: package up the results into a mergeable workspace (?)
for what in heur corr_usegray corr_nogray; do
  $ASHS_ROOT/ext/$(uname)/bin/c3d \
    $WORKDIR/ashs/final/${IDSTRING}_left_lfseg_${what}.nii.gz \
    $WORKDIR/ashs/final/${IDSTRING}_right_lfseg_${what}.nii.gz \
    -shift 100 -replace 100 0 -add \
    -o $WORKDIR/${IDSTRING}_lfseg_${what}.nii.gz
done

# Create a new workspace
itksnap-wt -i $WSFILE \
  -las $WORKDIR/${IDSTRING}_lfseg_corr_usegray.nii.gz -psn "JLF/CL result" \
  -las $WORKDIR/${IDSTRING}_lfseg_corr_nogray.nii.gz -psn "JLF/CL-lite result" \
  -las $WORKDIR/${IDSTRING}_lfseg_heur.nii.gz -psn "JLF result" \
  -labels-clear \
  -labels-add $ASHS_ATLAS/snap/snaplabels.txt 0 "Left %s" \
  -labels-add $ASHS_ATLAS/snap/snaplabels.txt 100 "Right %s" \
  -o $WSRESULT

