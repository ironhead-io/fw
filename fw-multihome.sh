#!/bin/bash -

# add debugging
set -ux

source firewall/services.sh

# Note, that this does not setup any of the devices, run fw-multihome-setup.sh to do that
IPTABLES=/usr/sbin/iptables
SSH_FW_PORT=2112
SSH_SERVICE_PORT=2882

test -x $IPTABLES || {
	printf "IPTables not installed, exiting.\n" > /dev/stderr
	exit 5
}


case "$1" in

# Start a new firewall
start)
printf "Starting firewall\n " >/dev/stderr

# Flush rules for filter and nat tables
echo $IPTABLES --flush
echo $IPTABLES --delete-chain
echo $IPTABLES --flush -t nat
echo $IPTABLES --delete-chain -t nat

# Set default
echo $IPTABLES -P INPUT DROP
echo $IPTABLES -P FORWARD DROP
echo $IPTABLES -P OUTPUT DROP

# Allow loopback connections
echo $IPTABLES -I INPUT 1 -i lo -j ACCEPT
echo $IPTABLES -I OUTPUT 1 -o lo -j ACCEPT

# Kick out spoofing requests
#$IPTABLES -A INPUT -s 192.168.0.0/16 -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
#$IPTABLES -A INPUT -s 192.168.0.0/16 -i $WAN_IFACE -j DROP
echo $IPTABLES -A INPUT -s 172.16.0.0/12 -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A INPUT -s 172.16.0.0/12 -i $WAN_IFACE -j DROP
echo $IPTABLES -A INPUT -s 10.0.0.0/8 -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A INPUT -s 10.0.0.0/8 -i $WAN_IFACE -j DROP
echo $IPTABLES -A INPUT ! -s $DMZ_NW -i $DMZ_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A INPUT ! -s $DMZ_NW -i $DMZ_IFACE -j DROP
echo $IPTABLES -A INPUT ! -s $LAN_NW -i $LAN_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A INPUT ! -s $LAN_NW -i $LAN_IFACE -j DROP
echo $IPTABLES -A INPUT ! -s $DMZ_NW -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A INPUT ! -s $DMZ_NW -i $WAN_IFACE -j DROP
echo $IPTABLES -A INPUT ! -s $LAN_IP -i $LAN_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A INPUT ! -s $LAN_IP -i $LAN_IFACE -j DROP
echo $IPTABLES -A INPUT ! -s $DMZ_IP -i $DMZ_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A INPUT ! -s $DMZ_IP -i $DMZ_IFACE -j DROP
echo $IPTABLES -A INPUT ! -s $WAN_IP -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A INPUT ! -s $WAN_IP -i $WAN_IFACE -j DROP

# Kick out spoofing requests
#$IPTABLES -A FORWARD -s 192.168.0.0/16 -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
#$IPTABLES -A FORWARD -s 192.168.0.0/16 -i $WAN_IFACE -j DROP
echo $IPTABLES -A FORWARD -s 172.16.0.0/12 -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A FORWARD -s 172.16.0.0/12 -i $WAN_IFACE -j DROP
echo $IPTABLES -A FORWARD -s 10.0.0.0/8 -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A FORWARD -s 10.0.0.0/8 -i $WAN_IFACE -j DROP
echo $IPTABLES -A FORWARD ! -s $DMZ_NW -i $DMZ_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A FORWARD ! -s $DMZ_NW -i $DMZ_IFACE -j DROP
echo $IPTABLES -A FORWARD ! -s $LAN_NW -i $LAN_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A FORWARD ! -s $LAN_NW -i $LAN_IFACE -j DROP
echo $IPTABLES -A FORWARD ! -s $DMZ_NW -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A FORWARD ! -s $DMZ_NW -i $WAN_IFACE -j DROP
echo $IPTABLES -A FORWARD ! -s $LAN_IP -i $LAN_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A FORWARD ! -s $LAN_IP -i $LAN_IFACE -j DROP
echo $IPTABLES -A FORWARD ! -s $DMZ_IP -i $DMZ_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A FORWARD ! -s $DMZ_IP -i $DMZ_IFACE -j DROP
echo $IPTABLES -A FORWARD ! -s $WAN_IP -i $WAN_IFACE -j LOG --log-prefix "Spoofed source IP"
echo $IPTABLES -A FORWARD ! -s $WAN_IP -i $WAN_IFACE -j DROP

# Inbound policy
# Accept inbound requests from OK'ed session
echo $IPTABLES -A INPUT -j ACCEPT -m state --state ESTABLISHED,RELATED
echo $IPTABLES -A INPUT -p tcp ! --syn -m state --state NEW -j LOG --log-prefix "Stealth scan attempt...?"
echo $IPTABLES -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
echo $IPTABLES -A INPUT -p tcp -s $LAN_NW --dport $SSH_FW_PORT -m state --state NEW -j ACCEPT 
echo $IPTABLES -A INPUT -j LOG --log-prefix "Dropped by default INPUT"
echo $IPTABLES -A INPUT -j DROP

# Outbound policy
echo $IPTABLES -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
# Comment this when ready to disable pings
echo $IPTABLES -A OUTPUT -p icmp -j ACCEPT
echo $IPTABLES -A OUTPUT -p udp --dport 53 -j ACCEPT
echo $IPTABLES -A OUTPUT -p tcp --dport 80 -j ACCEPT
echo $IPTABLES -A OUTPUT -j LOG --log-prefix "Dropped by default OUTPUT"
echo $IPTABLES -A OUTPUT -j DROP

# Forward policy
echo $IPTABLES -I FORWARD 1 -m state --state RELATED,ESTABLISHED -j ACCEPT
echo $IPTABLES -A FORWARD -p tcp ! --syn -m state --state NEW -j LOG --log-prefix "Stealth scan attempt...?"
echo $IPTABLES -A FORWARD -p tcp ! --syn -m state --state NEW -j DROP
echo $IPTABLES -A FORWARD -p tcp -d $SERVICE --dport 80 -m state --state NEW -j ACCEPT
echo $IPTABLES -A FORWARD -p udp -s $SERVICE -m state --state NEW,RELATED --dport 53 -j ACCEPT

# Forwarding rules for internal hosts
echo $IPTABLES -A FORWARD -p udp -s $LAN_NW -m state --state NEW,RELATED --dport 53 -j ACCEPT
echo $IPTABLES -A FORWARD -p tcp -s $LAN_NW -m state --state NEW --dport 80 -j ACCEPT
echo $IPTABLES -A FORWARD -p tcp -s $LAN_NW -m state --state NEW --dport 443 -j ACCEPT
echo $IPTABLES -A FORWARD -p tcp -s $LAN_NW -d $SERVICE -m state --state NEW --dport $SSH_SERVICE_PORT -j ACCEPT
echo $IPTABLES -A FORWARD -j LOG --log-prefix "Dropped by default OUTPUT"
echo $IPTABLES -A FORWARD -j DROP

# NAT firewall hiding
echo $IPTABLES -t nat -A POSTROUTING -s $LAN_NW -o $WAN_IFACE -j SNAT --to-source $WAN_IP
echo $IPTABLES -t nat -A POSTROUTING -s $LAN_NW -o $DMZ_IFACE -j SNAT --to-source $DMZ_IP

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
