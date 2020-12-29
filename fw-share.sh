#!/bin/bash -
# This script is a weird way for people who don't know much about 
# networking to test connectivity
source firewall/services.sh

# Turn on IP v4 forwarding (but this should be part of a script)
sysctl net.ipv4.ip_forward=1

# Turn on IP v6 forwarding as well
sysctl net.ipv6.conf.default.forwarding=1

# ...
sysctl net.ipv6.conf.all.forwarding=1

# Define arrays
IP_SET=( $DMZ_IP $LAN_IP )
IFACE_SET=( $DMZ_IFACE $LAN_IFACE )
NETMASK_SET=( $DMZ_NETMASK $LAN_NETMASK )
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

	# Enable different IP tables rules
	iptables -t nat -A POSTROUTING -o $WAN_IFACE -j MASQUERADE || {
		printf "Problem setting iptables rule...\n" > /dev/stderr
		exit 1
	}

	iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || {
		printf "Problem setting iptables rule...\n" > /dev/stderr
		exit 1
	}

	iptables -A FORWARD -i $IFACE -o $WAN_IFACE -j ACCEPT || {
		printf "Problem setting iptables rule...\n" > /dev/stderr
		exit 1
	}
done

# Add a temporary route from here to here?
#ip route add 99.27.159.146 via 172.16.2.100 dev $DMZ_IFACE

exit 0
