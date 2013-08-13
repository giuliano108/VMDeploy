#!/bin/bash
if [ "x$1" = 'x' ]; then
    ENVSWITCH=''
    ENVARG=''
else
    ENVSWITCH='--environment'
    ENVARG=$1 # we want this to fail if it contains spaces
fi
puppet apply $ENVSWITCH $ENVARG --modulepath=/etc/puppet-it/modules:/etc/puppet-it/profiles:/usr/share/puppet/modules --verbose --summarize --color=false --node_terminus exec --external_nodes /etc/puppet-it/puppet-it-enc.sh --show_diff /etc/puppet-it/manifests/site.pp
