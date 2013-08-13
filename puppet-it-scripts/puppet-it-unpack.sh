#!/bin/sh -eu

REV=$1
RELEASES=/etc/puppet-it-releases

mkdir -p $RELEASES 
tar xzf /root/puppet-it-${REV}.tar.gz -C $RELEASES

# Remove symlink folder
if [ -L /etc/puppet-it ]; then
  rm -f /etc/puppet-it
elif [ -e /etc/puppet-it ]; then # backup folder
  mv /etc/puppet-it $RELEASES/puppet-it-`date +%s`
fi

ln -sf /etc/puppet-it-releases/puppet-it-${REV}/puppet /etc/puppet-it
