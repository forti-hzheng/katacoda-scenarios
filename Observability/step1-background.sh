#!/bin/bash

echo Watiting for assets..
  while [ ! -f /usr/bin/k8s-install-1.23.sh ]
  do
    sleep 1
  done
k8s-install-1.23.sh
