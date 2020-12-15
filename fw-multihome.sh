#!/bin/bash -


# Internal subnet 
NET_INT=192.168.144.0/24

# DMZ subnet
#NET_DMZ=99.27.159.0/29
NET_DMZ=172.16.2.0/29

# The 
IFACE_INT=eno1

IFACE_DMZ=enp0s20u4

IFACE_EXT=enp0s20u3

IP_INT=192.168.144.100

IP_DMZ=172.16.2.1

IP_EXT=99.27.159.146

# The IP address of a server within the DMZ
SERVICE=172.16.2.100

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
$IPTABLES -I OUTPUT 1 -i lo -j ACCEPT

# Kick out spoofing requests
$IPTABLES -A INPUT -s 192.168.0.0/16 -i $IFACE_EXT -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A INPUT -s 192.168.0.0/16 -i $IFACE_EXT -j DROP
$IPTABLES -A INPUT -s 172.16.0.0/12 -i $IFACE_EXT -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A INPUT -s 172.16.0.0/12 -i $IFACE_EXT -j DROP
$IPTABLES -A INPUT -s 10.0.0.0/8 -i $IFACE_EXT -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A INPUT -s 10.0.0.0/8 -i $IFACE_EXT -j DROP
$IPTABLES -A INPUT -s ! $NET_DMZ -i $IFACE_DMZ -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A INPUT -s ! $NET_DMZ -i $IFACE_DMZ -j DROP
$IPTABLES -A INPUT -s ! $NET_INT -i $IFACE_INT -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A INPUT -s ! $NET_INT -i $IFACE_INT -j DROP
$IPTABLES -A INPUT -s ! $NET_DMZ -i $IFACE_EXT -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A INPUT -s ! $NET_DMZ -i $IFACE_EXT -j DROP
$IPTABLES -A INPUT -s ! $IP_INT -i $IFACE_INT -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A INPUT -s ! $IP_INT -i $IFACE_INT -j DROP
$IPTABLES -A INPUT -s ! $IP_DMZ -i $IFACE_DMZ -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A INPUT -s ! $IP_DMZ -i $IFACE_DMZ -j DROP
$IPTABLES -A INPUT -s ! $IP_EXT -i $IFACE_EXT -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A INPUT -s ! $IP_EXT -i $IFACE_EXT -j DROP

# Kick out spoofing requests
$IPTABLES -A FORWARD -s 192.168.0.0/16 -i $IFACE_EXT -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A FORWARD -s 192.168.0.0/16 -i $IFACE_EXT -j DROP
$IPTABLES -A FORWARD -s 172.16.0.0/12 -i $IFACE_EXT -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A FORWARD -s 172.16.0.0/12 -i $IFACE_EXT -j DROP
$IPTABLES -A FORWARD -s 10.0.0.0/8 -i $IFACE_EXT -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A FORWARD -s 10.0.0.0/8 -i $IFACE_EXT -j DROP
$IPTABLES -A FORWARD -s ! $NET_DMZ -i $IFACE_DMZ -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A FORWARD -s ! $NET_DMZ -i $IFACE_DMZ -j DROP
$IPTABLES -A FORWARD -s ! $NET_INT -i $IFACE_INT -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A FORWARD -s ! $NET_INT -i $IFACE_INT -j DROP
$IPTABLES -A FORWARD -s ! $NET_DMZ -i $IFACE_EXT -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A FORWARD -s ! $NET_DMZ -i $IFACE_EXT -j DROP
$IPTABLES -A FORWARD -s ! $IP_INT -i $IFACE_INT -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A FORWARD -s ! $IP_INT -i $IFACE_INT -j DROP
$IPTABLES -A FORWARD -s ! $IP_DMZ -i $IFACE_DMZ -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A FORWARD -s ! $IP_DMZ -i $IFACE_DMZ -j DROP
$IPTABLES -A FORWARD -s ! $IP_EXT -i $IFACE_EXT -j LOG --log-prefix "Spoofed source IP"
$IPTABLES -A FORWARD -s ! $IP_EXT -i $IFACE_EXT -j DROP

# Inbound policy
# Accept inbound requests from OK'ed session
$IPTABLES -A INPUT -j ACCEPT -m state --state ESTABLISHED,RELATED
$IPTABLES -A INPUT -p tcp ! --syn -m state --state NEW -j LOG --log-prefix "Stealth scan attempt...?"
$IPTABLES -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
$IPTABLES -A INPUT -p tcp -s $NET_INT --dport 22 -m state --state NEW -j ACCEPT 
$IPTABLES -A INPUT -j LOG --log-prefix "Dropped by default INPUT"
$IPTABLES -A INPUT -j DROP

# Outbound policy
$IPTABLES -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
$IPTABLES -A OUTPUT -p icmp -j ACCEPT
$IPTABLES -A OUTPUT -p udp --dport 53 -j ACCEPT
#$IPTABLES -A OUTPUT -p tcp --dport 80 -j ACCEPT
$IPTABLES -A OUTPUT -j LOG --log-prefix "Dropped by default OUTPUT"
$IPTABLES -A OUTPUT -j DROP

# Forward policy
$IPTABLES -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
$IPTABLES -A FORWARD -p tcp ! --syn -m state --state NEW -j LOG --log-prefix "Stealth scan attempt...?"
$IPTABLES -A FORWARD -p tcp ! --syn -m state --state NEW -j DROP
$IPTABLES -A FORWARD -p tcp -d $SERVICE --dport 80 -m state --state NEW -j ACCEPT
$IPTABLES -A FORWARD -p udp -s $SERVICE -m state --state NEW,RELATED --dport 53 -j ACCEPT

# Forwarding rules for internal hosts
$IPTABLES -A FORWARD -p udp -s $NET_INT -m state --state NEW,RELATED --dport 53 -j ACCEPT
$IPTABLES -A FORWARD -p tcp -s $NET_INT -m state --state NEW --dport 80 -j ACCEPT
$IPTABLES -A FORWARD -p tcp -s $NET_INT -m state --state NEW --dport 443 -j ACCEPT
$IPTABLES -A FORWARD -p tcp -s $NET_INT -d $SERVICE -m state --state NEW --dport 22 -j ACCEPT
$IPTABLES -A FORWARD -j LOG --log-prefix "Dropped by default OUTPUT"
$IPTABLES -A FORWARD -j DROP

# NAT firewall hiding
$IPTABLES -t nat -A POSTROUTING -s $NET_INT -o $IFACE_EXT -j SNAT --to-source $IP_EXT
$IPTABLES -t nat -A POSTROUTING -s $NET_INT -o $IFACE_DMZ -j SNAT --to-source $IP_DMZ

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
