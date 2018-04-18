#!/bin/bash -x
source dss_common.sh

# Get the command-line arguments
TICKET_ID=${1?}
WORKDIR=${2?}
WSFILE=${3?}
WSRESULT=${4?}

# Identify the T1 image
T1_FILE=$(itksnap-wt -P -i $WSFILE -llf T1)
if [[ $(echo $T1_FILE | wc -w) -ne 1 || ! -f $T1_FILE ]]; then
  fail_ticket $TICKET_ID "Missing tag 'T1' in ticket workspace"
  exit -1
fi

# Set the path to ASHS
export ASHS_ROOT=/home/ashs/tk/ashs-fast
ASHS_HARP_ATLAS=/home/ashs/tk/ashs_atlas_harp30/final
ASHS_ICV_ATLAS=/home/ashs/tk/ashs_atlas_icv/final

# Use the common hook script
export ASHS_HOOK_SCRIPT=$PWD/ashs_dss_hook.sh

#########################################################################
# ICV SEGMENTATION
#########################################################################

# Provide callback info for ASHS to update progress and send log messages
export ASHS_HOOK_DATA="$TICKET_ID,ICV,0.0,0.5"

# The 8-digit ticket id string
IDSTRING=$(printf %08d $TICKET_ID)

# Ready to roll!
$ASHS_ROOT/bin/ashs_main.sh \
  -a $ASHS_ICV_ATLAS \
  -g $T1_FILE -f $T1_FILE \
  -w $WORKDIR/ashs_icv \
  -I $IDSTRING \
  -H -B -Q -z $SCRIPTDIR/ashs_qsub_opts.sh

# Check the error code
if [[ $? -ne 0 ]]; then
  # TODO: we need to supply some debugging information, this is not enough
  # ASHS crashed - report the error
  fail_ticket $TICKET_ID "ASHS execution failed"
  exit -1
fi

#########################################################################
# HARP SEGMENTATION
#########################################################################

# Provide callback info for ASHS to update progress and send log messages
export ASHS_HOOK_DATA="$TICKET_ID,HARP,0.5,0.5"

# Ready to roll!
$ASHS_ROOT/bin/ashs_main.sh \
  -a $ASHS_HARP_ATLAS \
  -g $T1_FILE -f $T1_FILE \
  -w $WORKDIR/ashs_harp \
  -I $IDSTRING \
  -H -Q -z $SCRIPTDIR/ashs_qsub_opts.sh

# Check the error code
if [[ $? -ne 0 ]]; then
  # TODO: we need to supply some debugging information, this is not enough
  # ASHS crashed - report the error
  fail_ticket $TICKET_ID "ASHS execution failed"
  exit -1
fi

#########################################################################
# PACKAGE UP ICV-HARP
#########################################################################

# TODO: package up the results into a mergeable workspace (?)
#for what in heur corr_usegray corr_nogray; do
for what in corr_nogray ; do
  $ASHS_ROOT/ext/$(uname)/bin/c3d \
    $WORKDIR/ashs_icv/final/${IDSTRING}_left_lfseg_${what}.nii.gz \
    -shift 100 -replace 100 0 \
    -o $WORKDIR/${IDSTRING}_icv_lfseg_${what}.nii.gz

  $ASHS_ROOT/ext/$(uname)/bin/c3d \
    $WORKDIR/ashs_harp/final/${IDSTRING}_left_lfseg_${what}.nii.gz \
    -shift 101 -replace 101 0 \
    $WORKDIR/ashs_harp/final/${IDSTRING}_right_lfseg_${what}.nii.gz \
    -shift 102 -replace 102 0 -add \
    -o $WORKDIR/${IDSTRING}_left_right_lfseg_${what}.nii.gz
done

# Create a new workspace
itksnap-wt -i $WSFILE \
  -las $WORKDIR/${IDSTRING}_icv_lfseg_${what}.nii.gz -psn "ICV" \
  -las $WORKDIR/${IDSTRING}_left_right_lfseg_${what}.nii.gz -psn "HARP" \
  -labels-clear \
  -labels-add $SCRIPTDIR/snaplabels.txt 100 \
  -o $WSRESULT

