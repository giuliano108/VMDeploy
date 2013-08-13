#!/bin/sh -eu

# External Node Classifier script

if [ -r /etc/puppet-it/declared_classes.yaml ]; then
  /bin/cat /etc/puppet-it/declared_classes.yaml
else
  cat <<EOF
--- 
classes: []
EOF
fi
