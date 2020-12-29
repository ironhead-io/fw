#!/bin/bash -

source services.sh

# Find all devices besides loop back and turn them off
ip link set up dev $LAN_IFACE || {
	printf "Failed to activate LAN interface\n" > /dev/stderr
	exit 1
}

ip addr add $LAN_IP/$LAN_NETMASK dev $LAN_IFACE || {
	printf "Failed to add ip to LAN i/f\n" > /dev/stderr
	exit 1
}

ip link set up dev $DMZ_IFACE || { \
	printf "Failed to activate DMZ interface\n" > /dev/stderr
	exit 1
}

ip addr add $DMZ_IP/$DMZ_NETMASK dev $DMZ_IFACE || {
	printf "Failed to add ip to DMZ i/f\n" > /dev/stderr
	exit 1
}

exit 0
