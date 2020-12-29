#!/bin/bash -
set -ux
IPTABLES=/usr/sbin/iptables
SERVER_TEST_PORT=2020

source firewall/services.sh

# send stuff to server
$IPTABLES -t nat -A PREROUTING -i $WAN_IFACE -p tcp --dport 80 \
	-j DNAT --to-destination $SERVICE:$SERVER_TEST_PORT

# add a rule to send it back
$IPTABLES -t nat -A POSTROUTING -o $WAN_IFACE -j SNAT --to-source $WAN_IP 

