#!/bin/bash -

# This should set up DMZ and all

# add debugging
set -ux

source services.sh

# Note, that this does not setup any of the devices, run fw-multihome-setup.sh to do that
IPTABLES=/usr/sbin/iptables

test -x $IPTABLES || {
	printf "IPTables not installed, exiting.\n" > /dev/stderr
	exit 5
}


case "$1" in
# Start a new firewall
start)
	printf "Starting firewall\n " >/dev/stderr

	# Flush rules for filter and nat tables
	$IPTABLES --flush
	$IPTABLES --delete-chain
	$IPTABLES --flush -t nat
	$IPTABLES --delete-chain -t nat

	# Set default
	$IPTABLES -P INPUT DROP
	$IPTABLES -P FORWARD DROP
	$IPTABLES -P OUTPUT DROP

	# Allow loopback connections
	$IPTABLES -I INPUT 1 -i lo -j ACCEPT
	$IPTABLES -I OUTPUT 1 -o lo -j ACCEPT

	# Kick out spoofing requests
	$IPTABLES -A INPUT -s 192.168.0.0/16 -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A INPUT -s 192.168.0.0/16 -i $WAN_IFACE -j DROP
	$IPTABLES -A INPUT -s 172.16.0.0/12 -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A INPUT -s 172.16.0.0/12 -i $WAN_IFACE -j DROP
	$IPTABLES -A INPUT -s 10.0.0.0/8 -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A INPUT -s 10.0.0.0/8 -i $WAN_IFACE -j DROP
	$IPTABLES -A INPUT ! -s $DMZ_NW -i $DMZ_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A INPUT ! -s $DMZ_NW -i $DMZ_IFACE -j DROP
	$IPTABLES -A INPUT ! -s $LAN_NW -i $LAN_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A INPUT ! -s $LAN_NW -i $LAN_IFACE -j DROP
	$IPTABLES -A INPUT ! -s $DMZ_NW -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A INPUT ! -s $DMZ_NW -i $WAN_IFACE -j DROP
	$IPTABLES -A INPUT ! -s $LAN_IP -i $LAN_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A INPUT ! -s $LAN_IP -i $LAN_IFACE -j DROP
	$IPTABLES -A INPUT ! -s $DMZ_IP -i $DMZ_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A INPUT ! -s $DMZ_IP -i $DMZ_IFACE -j DROP
	$IPTABLES -A INPUT ! -s $WAN_IP -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A INPUT ! -s $WAN_IP -i $WAN_IFACE -j DROP

	# Kick out spoofing requests
	$IPTABLES -A FORWARD -s 192.168.0.0/16 -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A FORWARD -s 192.168.0.0/16 -i $WAN_IFACE -j DROP
	$IPTABLES -A FORWARD -s 172.16.0.0/12 -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A FORWARD -s 172.16.0.0/12 -i $WAN_IFACE -j DROP
	$IPTABLES -A FORWARD -s 10.0.0.0/8 -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A FORWARD -s 10.0.0.0/8 -i $WAN_IFACE -j DROP
	$IPTABLES -A FORWARD ! -s $DMZ_NW -i $DMZ_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A FORWARD ! -s $DMZ_NW -i $DMZ_IFACE -j DROP
	$IPTABLES -A FORWARD ! -s $LAN_NW -i $LAN_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A FORWARD ! -s $LAN_NW -i $LAN_IFACE -j DROP
	$IPTABLES -A FORWARD ! -s $DMZ_NW -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A FORWARD ! -s $DMZ_NW -i $WAN_IFACE -j DROP
	$IPTABLES -A FORWARD ! -s $LAN_IP -i $LAN_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A FORWARD ! -s $LAN_IP -i $LAN_IFACE -j DROP
	$IPTABLES -A FORWARD ! -s $DMZ_IP -i $DMZ_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A FORWARD ! -s $DMZ_IP -i $DMZ_IFACE -j DROP
	$IPTABLES -A FORWARD ! -s $WAN_IP -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
	$IPTABLES -A FORWARD ! -s $WAN_IP -i $WAN_IFACE -j DROP

	# Inbound policy
	# Accept inbound requests from OK'ed session
	$IPTABLES -A INPUT -j ACCEPT -m state --state ESTABLISHED,RELATED
	$IPTABLES -A INPUT -p tcp ! --syn -m state --state NEW -j LOG --log-prefix "Stealth scan attempt...?"
	$IPTABLES -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
	$IPTABLES -A INPUT -p tcp -s $LAN_NW --dport $SSH_FW_PORT -m state --state NEW -j ACCEPT 
	$IPTABLES -A INPUT -j LOG --log-prefix "Dropped by default INPUT"
	$IPTABLES -A INPUT -j DROP

	# Outbound policy
	$IPTABLES -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	# Comment this when ready to disable pings
	$IPTABLES -A OUTPUT -p icmp -j ACCEPT
	$IPTABLES -A OUTPUT -p udp --dport 53 -j ACCEPT
	$IPTABLES -A OUTPUT -p tcp --dport 80 -j ACCEPT
	$IPTABLES -A OUTPUT -j LOG --log-prefix "Dropped by default OUTPUT"
	$IPTABLES -A OUTPUT -j DROP

	# Forward policy
	$IPTABLES -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
	$IPTABLES -A FORWARD -p tcp ! --syn -m state --state NEW -j LOG --log-prefix "Stealth scan attempt...?"
	$IPTABLES -A FORWARD -p tcp ! --syn -m state --state NEW -j DROP
	$IPTABLES -A FORWARD -p tcp -d $SERVICE --dport 80 -m state --state NEW -j ACCEPT
	$IPTABLES -A FORWARD -p udp -s $SERVICE -m state --state NEW,RELATED --dport 53 -j ACCEPT

	# Forwarding rules for internal hosts
	$IPTABLES -A FORWARD -p udp -s $LAN_NW -m state --state NEW,RELATED --dport 53 -j ACCEPT
	$IPTABLES -A FORWARD -p tcp -s $LAN_NW -m state --state NEW --dport 80 -j ACCEPT
	$IPTABLES -A FORWARD -p tcp -s $LAN_NW -m state --state NEW --dport 443 -j ACCEPT
	$IPTABLES -A FORWARD -p tcp -s $LAN_NW -d $SERVICE -m state --state NEW --dport $SSH_SERVICE_PORT -j ACCEPT
	$IPTABLES -A FORWARD -j LOG --log-prefix "Dropped by default OUTPUT"
	$IPTABLES -A FORWARD -j DROP

	# NAT firewall hiding
	$IPTABLES -t nat -A POSTROUTING -s $LAN_NW -o $WAN_IFACE -j SNAT --to-source $WAN_IP
	$IPTABLES -t nat -A POSTROUTING -s $LAN_NW -o $DMZ_IFACE -j SNAT --to-source $DMZ_IP

	;;


wideopen)

;;

stop)
	printf "Stopping firewall\n " >/dev/stderr
	$IPTABLES --flush
;;


status)
;;


*)
	printf "Usage: $0 {start|stop|status}\n"
	exit 1
;;


esac

exit 0
