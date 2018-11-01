#!/bin/bash
WORKDIR=${1?}
STAGE=${2?}

case $STAGE in
  1) 
    echo "-pe serial 24"
    ;;
  3) 
    echo "-pe serial 24"
    ;;
  4)
    echo "-l h_rt=00:03:00 -l h_rt=00:02:00"
    ;;
  5)
    echo "-pe serial 24"
    ;;
esac


