#!/bin/bash -

# I wonder, would it be easier to make a Makefile for this?
# This script is a weird way for people who don't know much about 
# networking to test connectivity
set -ux
source firewall/services.sh

function help() {
	cat <<EOF
Show all the options...
EOF
}


case "$1" in
# Try simple forwarding
forward)

	# Turn on IP v4 forwarding (but this should be part of a script)
	sysctl net.ipv4.ip_forward=1

	# Turn on IP v6 forwarding as well
	sysctl net.ipv6.conf.default.forwarding=1

	# ...
	sysctl net.ipv6.conf.all.forwarding=1

	# Why is this defined this way?
	IPTABLES=/usr/sbin/iptables

	# Define arrays
	IP_SET=( $DMZ_IP $LAN_IP )
	IFACE_SET=( $DMZ_IFACE $LAN_IFACE )
	NETMASK_SET=( $DMZ_NETMASK $LAN_NETMASK )

	# Flush rules for filter and nat tables
	$IPTABLES --flush
	$IPTABLES --delete-chain
	$IPTABLES --flush -t nat
	$IPTABLES --delete-chain -t nat

	# Enable different IP tables rules
	$IPTABLES -t nat -A POSTROUTING -o $WAN_IFACE -j SNAT --to $WAN_IP || {
		printf "Problem setting $IPTABLES rule...\n" > /dev/stderr
		exit 1
	}

	# This looks like an accounting rule
	#$IPTABLES -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || {
	#	printf "Problem setting $IPTABLES rule...\n" > /dev/stderr
	#	exit 1
	#}


	for i in `seq 0 $(( ${#IP_SET[@]} - 1 ))` 
	do
		# Define IPs
		IP=${IP_SET[ $i ]}
		IFACE=${IFACE_SET[ $i ]}
		NETMASK=${NETMASK_SET[ $i ]}

		# Turn interface on
		ip link set up dev $IFACE

		# Add the IP we specified
		ip addr add $IP/$NETMASK dev $IFACE

		# Set both interfaces to forward out?
		$IPTABLES -A FORWARD -i $IFACE -o $WAN_IFACE -j ACCEPT || {
			printf "Problem setting iptables rule...\n" > /dev/stderr
			exit 1
		}
	done

	# Add a temporary route from here to here?
	#ip route add 99.27.159.146 via 172.16.2.100 dev $DMZ_IFACE

	exit 0
;;


# stop the firewall
stop)
	printf "Unloading firewall rules\n " >/dev/stderr
	$IPTABLES --flush
;;


# completely stop the firewall
allstop)
	# Flush rules for filter and nat tables
	$IPTABLES --flush
	$IPTABLES --delete-chain
	$IPTABLES --flush -t nat
	$IPTABLES --delete-chain -t nat

	# Set default
	$IPTABLES -P INPUT ACCEPT
	$IPTABLES -P FORWARD ACCEPT
	$IPTABLES -P OUTPUT ACCEPT
;;


*)
	printf "Usage: $0 {start|stop|status}\n"
	exit 1
;;

esac



