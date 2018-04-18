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
  5)
    echo "-pe serial 24"
    ;;
esac


