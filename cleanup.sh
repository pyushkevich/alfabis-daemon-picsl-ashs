#!/bin/bash
WORK=/home/ashs_sandbox/dss/dss_daemon/work
pushd $WORK
for fn in $(find . -maxdepth 1 -ctime +30 -type d | sort)
do 
  rm -rf $fn
done
popd
