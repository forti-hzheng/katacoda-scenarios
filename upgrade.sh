#!/bin/bash

echo Waiting for Kubernetes to start...
echo This might take up 5 minutes...
echo Do NOT press continue until your environment is ready...
  while [ ! -f /root/.kube/installed ]
  do
    sleep 1
  done
echo Kubernetes started

export do="--dry-run=client -o yaml"
echo "set tabstop=2" >> ~/.vimrc
echo "set expandtab" >> ~/.vimrc

echo "use $do == --dry-run=client -o=yaml"

complete -F __start_kubectl k
