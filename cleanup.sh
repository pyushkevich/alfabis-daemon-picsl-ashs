#!/bin/bash
WORK=/home/ashs/dss/dss_daemon/work
pushd $WORK
for fn in $(find . -maxdepth 1 -ctime +7 -type d | sort)
do 
  rm -rf $fn
done
popd
