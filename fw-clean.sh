#!/bin/bash -

# add debugging
set -ux

# get vars
source firewall/services.sh

IPTABLES=/usr/sbin/iptables
test -x $IPTABLES || {
	printf "IPTables not installed, exiting.\n" > /dev/stderr
	exit 5
}

# Flush rules for filter and nat tables
$IPTABLES --flush
$IPTABLES --delete-chain
$IPTABLES --flush -t nat
$IPTABLES --delete-chain -t nat


exit 0


