#!/bin/sh -
# 
# fw
# ==
# An iptables firewall rule script.
#
# Usage:
# fw <type> [ <interface>, <interface1, interface2, ..., interfaceN> ]
#
# Rationale:
# Multihome firewalls often rely on setting up rules for specific interfaces.
# However, the way to get these interface names varies somewhat wildly on 
# different systems depending on what internet configuration tooling is installed.
# 
# This script will assume this and make changes based on supplied arguments
# rather than trying to invoke itself with the right hard-coded values at runtime. 
#
# Changelog: 
# -
#
# Todo: 
# - Get SUBNET_BASE added in 
# - Get ISP added in 
# - Add ipv6 support
# - Get ISP added in 
# - Split out "recipes" into their own files?
# - Change the log path
# - Read from the log, and handle rotation
# 

# Stop at unset variable usage
#set -u
#set -ux


# Set default variables here
IPT=/sbin/iptables
WAN_IFACE=
LOOPBACK_IFACE="lo"
IP_ADDRESS=
ISP=
SUBNET_BASE= # Example for local n/w would be: 192.168.1.0
SUBNET_BCAST= # Example for local n/w would be: 192.168.1.255
LOOPBACK="127.0.0.0/8"
CLASS_A="192.168.0.0/16"
CLASS_B="172.16.0.0/12"
CLASS_C="10.0.0.0/8"
CLASS_D_MULTICAST="224.0.0.0/4"
CLASS_E_RESERVED="240.0.0.0/5"
BCAST_SRC="0.0.0.0"
BCAST_DEST="255.255.255.255"
PRIV_PORTS="0:1023"
UNPRIV_PORTS="1024:65535"
KERN_PATH=/proc/sys/net/ipv4
USE_CONN_TRACKING=1
SSH_PORT=
SSH_ALLOWED_IP=
LOG_PATH=

# TODO: All of these extra ports MAY get hard to maintain...
# Coming up with a way to enable and disable common services would probably be easiest
ENABLE_SSH=
ENABLE_HTTP=
ENABLE_HTTPS=
# TODO: None of these are quite done yet
#ENABLE_FTP=
#ENABLE_SFTP=
#ENABLE_ICMP=
#ENABLE_IMAP=
#ENABLE_POP=
#ENABLE_SMTP=

# Mark actions seperately (these would be const enums or something in C)
DO_DEFAULT=0
DO_DUMP=1
DO_STOP=2
DO_SINGLE_HOME=3
DO_MULTI_HOME=4
#DO_MODIFY=5 # TODO: Use this to add rules to an already running firewall
ACTION=


# If iptables is not here, we shouldn't move forward
if test -z "$IPT" || test ! -x $IPT
then 
	printf "fw: iptables is not present.  " > /dev/stderr
	printf "Please install 'iptables' before moving forward.\n" > /dev/stderr
	exit 0
fi


# Utility to extract IP from one side of a variable
function chop_at_colon() {
	# Make an array
	ARR=$1
	WORD=0

	# If the character is there, return one item, if not, return both
	for n in `seq 0 $(( ${#ARR} - 1 ))`; do test ${ARR:$n:1} == ':' && WORD=1 && break; done

	# Return an array
	test $WORD -eq 1 && echo ${ARR%%:*} ${ARR#*:} || echo $ARR	
}


# Dump the configuration settings (should die if unset)
function dump_settings() {
	printf "%-20s: %s\n" "WAN_IFACE" $WAN_IFACE
	printf "%-20s: %s\n" "LOOPBACK_IFACE" $LOOPBACK_IFACE
	printf "%-20s: %s\n" "IP_ADDRESS" $IP_ADDRESS
	printf "%-20s: %s\n" "ISP" $ISP
	printf "%-20s: %s\n" "SUBNET_BASE" $SUBNET_BASE
	printf "%-20s: %s\n" "SUBNET_BCAST" $SUBNET_BCAST
	printf "%-20s: %s\n" "LOOPBACK" $LOOPBACK
	printf "%-20s: %s\n" "CLASS_A" $CLASS_A
	printf "%-20s: %s\n" "CLASS_B" $CLASS_B
	printf "%-20s: %s\n" "CLASS_C" $CLASS_C
	printf "%-20s: %s\n" "CLASS_D_MULTICAST" $CLASS_D_MULTICAST
	printf "%-20s: %s\n" "CLASS_E_RESERVED" $CLASS_E_RESERVED
	printf "%-20s: %s\n" "BCAST_SRC" $BCAST_SRC
	printf "%-20s: %s\n" "BCAST_DEST" $BCAST_DEST
	printf "%-20s: %s\n" "PRIV_PORTS" $PRIV_PORTS
	printf "%-20s: %s\n" "UNPRIV_PORTS" $UNPRIV_PORTS
	printf "%-20s: %s\n" "KERN_PATH" $KERN_PATH
	printf "%-20s: %s\n" "LOG_PATH" $LOG_PATH
	printf "%-20s: %s\n" "USE_CONN_TRACKING" $USE_CONN_TRACKING
}


# Set defaults here
function set_defaults() {
	#echo 1 > $KERN_PATH/icmp_echo_ignore_broadcasts # Might not be useful to do this yet...
	echo "1" > $KERN_PATH/tcp_syncookies
	for f in $KERN_PATH/conf/*/accept_source_route; do echo "0" > $f; done
	for f in $KERN_PATH/conf/*/accept_redirects; do echo "0" > $f; done
	for f in $KERN_PATH/conf/*/send_redirects; do echo "0" > $f; done
	for f in $KERN_PATH/conf/*/rp_filter; do echo "1" > $f; done
	for f in $KERN_PATH/conf/*/log_martians; do echo "1" > $f; done

	$IPT --flush
	$IPT -t nat --flush
	$IPT -t mangle --flush

	$IPT -X
	$IPT -t nat -X
	$IPT -t mangle -X

	$IPT --policy INPUT ACCEPT
	$IPT --policy OUTPUT ACCEPT
	$IPT --policy FORWARD ACCEPT

	$IPT -t nat --policy PREROUTING ACCEPT
	$IPT -t nat --policy OUTPUT ACCEPT
	$IPT -t nat --policy POSTROUTING ACCEPT

	$IPT -t mangle --policy PREROUTING ACCEPT
	$IPT -t mangle --policy OUTPUT ACCEPT
}


# Set drop here
function set_drop() {
	# Drop anything coming to or from the box by default
	$IPT --policy INPUT DROP
	$IPT --policy OUTPUT DROP
	$IPT --policy FORWARD DROP

	# Allow the loopback interface to accept everything
	$IPT -A INPUT -i lo -j ACCEPT
	$IPT -A OUTPUT -o lo -j ACCEPT
}


# Set forwarding
function set_forward() {
	$IPT -t nat -A POSTROUTING -s $LAN_NW -o $WAN_IFACE -j SNAT --to-source $WAN_IP
	$IPT -t nat -A POSTROUTING -s $LAN_NW -o $DMZ_IFACE -j SNAT --to-source $DMZ_IP
}


# Turn on state tracking (Good for machines or nodes with higher memory)
function set_state_tracking() {
	# Turn on state tracking for the purposes of this script 
	USE_CONN_TRACKING=1

	# Then monitor state on established connections
	$IPT -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
	$IPT -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
	
	# These could break long-running HTTP or HTTP/2 connections b/c
	# they by default drop any bi-direction connections
	$IPT -A INPUT -m state --state INVALID -j LOG --log-prefix "INVALID input: "
	$IPT -A INPUT -m state --state INVALID -j DROP
	$IPT -A OUTPUT -m state --state INVALID -j LOG --log-prefix "INVALID output: " 
	$IPT -A OUTPUT -m state --state INVALID -j DROP
}


# Log and drop spoofed packets
function set_logdrop_spoof() {
	# Drop packets claiming to be from myself
	$IPT -A INPUT -i $WAN_IFACE -s $IP_ADDRESS -j DROP

	# Drop packets coming from any class A, B or C addresses
	$IPT -A INPUT -i $WAN_IFACE -s $CLASS_A -j DROP 
	$IPT -A INPUT -i $WAN_IFACE -s $CLASS_B -j DROP 
	$IPT -A INPUT -i $WAN_IFACE -s $CLASS_C -j DROP 

	# Drop packets coming from loopback interface
	$IPT -A INPUT -i $WAN_IFACE -s $LOOPBACK -j DROP 

	# Drop packets from bad broadcast addressess
	$IPT -A INPUT -i $WAN_IFACE -s $BCAST_DEST -j LOG
	$IPT -A INPUT -i $WAN_IFACE -s $BCAST_DEST -j DROP 
	$IPT -A INPUT -i $WAN_IFACE -s $BCAST_SRC -j LOG
	$IPT -A INPUT -i $WAN_IFACE -s $BCAST_SRC -j DROP 
	
	# Refuse directed broadcasts (helps gauge effectiveness of a DoS attack)
	#$IPT -A INPUT -i $WAN_IFACE -d $SUBNET_BASE -j DROP
	#$IPT -A INPUT -i $WAN_IFACE -d $SUBNET_BCAST -j DROP

	# Refuse limited broadcasts
	$IPT -A INPUT -i $WAN_IFACE -d $BCAST_DEST -j DROP
	
	# Refuse Class D multicast packets
	$IPT -A INPUT -i $WAN_IFACE -d $CLASS_D_MULTICAST -j DROP

	# Refuse multicast packets using anything besides UDP
	$IPT -A INPUT -i $WAN_IFACE ! -p udp -d $CLASS_D_MULTICAST -j DROP

	# Allow valid multicast packets (might be needed for Zoom, etc)
	$IPT -A INPUT -i $WAN_IFACE -p udp -d $CLASS_D_MULTICAST -j ACCEPT

	# Refuse packets claiming to be from Class E addresses
	$IPT -A INPUT -i $WAN_IFACE -s $CLASS_E_RESERVED -j DROP
}


# In case of compromise, make it impossible (or difficult) for
# an intruder to connect to commonly running services
function set_disallow_common_services () {
	XWINDOW_PORTS="6000:6063" # Ports for TCP XWindow connections
	$IPT -A OUTPUT -o $WAN_IFACE -p tcp --syn \
		--destination-port $XWINDOW_PORTS -j REJECT

	# None of my machines ought to be running XWindows, but
	# I'm going to put this rule here anyway
	$IPT -A INPUT -i $WAN_IFACE -p tcp --syn \
		--destination-port $XWINDOW_PORTS -j DROP

	# Other services can be added here in the future, but 
	# I wonder if it would be easier from a maintenance 
	# standpoint to trigger the above rules once for each
	# service 
}


# Allow DNS
function set_allow_dns () {
	# I'm using Google by default
	NAMESERVER="8.8.8.8"

	if [ $USE_CONN_TRACKING == 1 ]
	then	
		$IPT -A OUTPUT -o $WAN_IFACE -p udp -s $IP_ADDRESS --sport $UNPRIV_PORTS \
			-d $NAMESERVER --dport 53 -m state --state NEW -j ACCEPT
	fi

	$IPT -A OUTPUT -o $WAN_IFACE -p udp -s $IP_ADDRESS --sport $UNPRIV_PORTS \
		-d $NAMESERVER --dport 53 -j ACCEPT

	$IPT -A INPUT -i $WAN_IFACE -p udp -s $NAMESERVER --sport 53 \
		-d $IP_ADDRESS --dport $UNPRIV_PORTS -j ACCEPT

	# Handle DNS over TCP
	if [ $USE_CONN_TRACKING == 1 ]
	then	
		$IPT -A OUTPUT -o $WAN_IFACE -p tcp -s $IP_ADDRESS --sport $UNPRIV_PORTS \
			-d $NAMESERVER --dport 53 -m state --state NEW -j ACCEPT
	fi

	$IPT -A OUTPUT -o $WAN_IFACE -p tcp -s $IP_ADDRESS --sport $UNPRIV_PORTS \
		-d $NAMESERVER --dport 53 -j ACCEPT

	$IPT -A INPUT -i $WAN_IFACE -p tcp ! --syn -s $NAMESERVER --sport 53 \
		-d $IP_ADDRESS --dport $UNPRIV_PORTS -j ACCEPT

	# TODO: Will need another rule to allow a forwarding DNS server
	# This should cut down on the times we need to access Google's DNS server
	# I'm unsure if this will affect the servers' DNS lookup time.
}


# Allow mail (obviously, I'm not ready for this yet)
function set_allow_mail() {
	printf ''>/dev/null
}


# Allow SSH
function set_allow_incoming_ssh() {
	SSH_PORTS="1024:65535"
	_SSH_PORT=$1
	_SSH_ALLOWED_IP="$2"
	if [ -z "$_SSH_PORT" ] 
	then
		printf "fw: No port specified for new incoming TCP rule.\n" > /dev/stderr
		exit 1;
	fi

	if [ -z $_SSH_ALLOWED_IP ]
	then
		# Allow access from the outside world
		if [ $USE_CONN_TRACKING == 1 ]
		then	
			$IPT -A INPUT -i $WAN_IFACE -p tcp --sport $SSH_PORTS \
				-d $IP_ADDRESS --dport $_SSH_PORT -m state --state NEW -j ACCEPT
		fi

		$IPT -A INPUT -i $WAN_IFACE -p tcp --sport $SSH_PORTS \
			-d $IP_ADDRESS --dport $_SSH_PORT -j ACCEPT

		$IPT -A OUTPUT -o $WAN_IFACE -p tcp ! --syn -s $IP_ADDRESS \
			--sport $_SSH_PORT --dport $SSH_PORTS -j ACCEPT
	else
		# Allow access from a specific user (or set of users?) 
		if [ $USE_CONN_TRACKING == 1 ]
		then	
			$IPT -A INPUT -i $WAN_IFACE -p tcp --sport $SSH_PORTS -s $_SSH_ALLOWED_IP \
				-d $IP_ADDRESS --dport $_SSH_PORT -m state --state NEW -j ACCEPT
		fi

		$IPT -A INPUT -i $WAN_IFACE -p tcp --sport $SSH_PORTS -s $_SSH_ALLOWED_IP \
			-d $IP_ADDRESS --dport $_SSH_PORT -j ACCEPT

		$IPT -A OUTPUT -o $WAN_IFACE -p tcp ! --syn -s $IP_ADDRESS \
			--sport $_SSH_PORT --dport $SSH_PORTS -d $_SSH_ALLOWED_IP -j ACCEPT
	fi
}


# Allow outgoing SSH (more important for multi-homed hosts)
function set_allow_outgoing_ssh() {
	# For a multi-homed host, I'll need this
#	if [ $USE_CONN_TRACKING == 1 ]
#	then	
#		$IPT -A OUTPUT -o $WAN_IFACE -p tcp -s $IP_ADDRESS --sport $SSH_PORTS \
#			--dport $SSH_ACCESS_PORT -m state --state NEW -j ACCEPT
#	fi
#
#	$IPT -A OUTPUT -o $WAN_IFACE -p tcp -s $IP_ADDRESS --sport $SSH_PORTS \
#		--dport $SSH_ACCESS_PORT -j ACCEPT
#
#	$IPT -A INPUT -i $WAN_IFACE -p tcp ! --syn \
#		--sport $SSH_ACCESS_PORT -d $IP_ADDRESS --dport $SSH_PORTS -j ACCEPT
	printf '' >/dev/null
}


# Allow outgoing generic TCP connection
function set_allow_outgoing_generic_tcp() {
	OPORTS=$1
	for PORT in ${OPORTS[@]}
	do
		if [ -z "$1" ] 
		then
			printf "fw: No port specified for outgoing TCP rule.\n" > /dev/stderr
			exit 1;
		fi

		# Allow outgoing TCP connection
		if [ $USE_CONN_TRACKING == 1 ]
		then	
			$IPT -A OUTPUT -o $WAN_IFACE -p tcp -s $IP_ADDRESS --sport $UNPRIV_PORTS \
				--dport $PORT -m state --state NEW -j ACCEPT
		fi

		$IPT -A OUTPUT -o $WAN_IFACE -p tcp -s $IP_ADDRESS --sport $UNPRIV_PORTS \
			--dport $PORT -j ACCEPT
		
		$IPT -A INPUT -i $WAN_IFACE -p tcp ! --syn --sport $PORT \
			-d $IP_ADDRESS --dport $UNPRIV_PORTS -j ACCEPT
	done
}


# Allow incoming generic TCP connection
function set_allow_incoming_generic_tcp() {
	IPORTS=$@
	if [ -z "$IPORTS" ] 
	then
		printf "fw: No port specified for new incoming TCP rule.\n" > /dev/stderr
		exit 1;
	fi

	for PORT in ${IPORTS[@]}
	do
		if [ $USE_CONN_TRACKING == 1 ]
		then	
			$IPT -A INPUT -i $WAN_IFACE -p tcp --sport $UNPRIV_PORTS \
				-d $IP_ADDRESS --dport $PORT -m state --state NEW -j ACCEPT
		fi

		$IPT -A INPUT -i $WAN_IFACE -p tcp --sport $UNPRIV_PORTS \
			-d $IP_ADDRESS --dport $PORT -j ACCEPT
		
		$IPT -A OUTPUT -o $WAN_IFACE -p tcp ! --syn -s $IP_ADDRESS \
			--dport $UNPRIV_PORTS -j ACCEPT
	done
}


# Allow outgoing connections to NTP
function set_allow_ntp_outgoing() {
	# If I use an external TIMESERVER
	TIMESERVER=

	# Allow outgoing TCP connection
	if [ $USE_CONN_TRACKING == 1 ]
	then	
		$IPT -A OUTPUT -o $WAN_IFACE -p udp -s $IP_ADDRESS --sport $UNPRIV_PORTS \
			-d $TIMESERVER --dport 123 -m state --state NEW -j ACCEPT
	fi

	$IPT -A OUTPUT -o $WAN_IFACE -p udp -s $IP_ADDRESS --sport $UNPRIV_PORTS \
		--dport $TIMESERVER --dport 123 -j ACCEPT
	
	$IPT -A INPUT -i $WAN_IFACE -p udp -s $TIMESERVER --sport 123 \
		-d $IP_ADDRESS --dport $UNPRIV_PORTS -j ACCEPT
}


# Allow logging of all dropped incoming packets
function set_log_all_incoming_dropped() {
	$IPT -A INPUT -i $WAN_IFACE -j LOG
}


# Allow logging of all dropped outgoing packets
function set_log_all_outgoing_dropped() {
	$IPT -A OUTPUT -o $WAN_IFACE -j LOG
}


# Show help
function show_help() {
	cat <<EOF
Usage: ./fw [options]

Arguments:
-w, --wan <arg:[ip]>      Specify the WAN interface (& an optional IP address)
-d, --dmz <arg:[ip]>      Specify the DMZ interface (& an optional IP address)
-l, --lan <arg:[ip]>      Specify the LAN interface (& an optional IP address)
-s, --ssh <arg:[ip]>      Specify a port (& an optional IP address to listen 
                          out for) for SSH connections
-i, --ip-address <arg>    Specify an IP for the WAN interface 
                          (if DMZ or LAN are not specified)
-b, --subnet-base <arg>   Specify a subnet base
-c, --subnet-bcast <arg>  Specify a subnet broadcast
-p, --log-path <arg>      Specify an alternate log path for firewall messages 

Actions:
-x, --dump                Dump the currently loaded variables 
    --deny                Flush any rules and go back to deny-by-default policy.
    --stop                Totally stop the firewall.
    --single-home         Start a single home firewall.
    --multi-home          Start a multi home firewall.

Common Ports:
    --http                Enable default HTTP port.
    --https               Enable default HTTPS port.
-h, --help                Show help.
EOF
	exit ${1:-0}
}


# Die if no options specified
if [ $# -lt 1 ]
then
	printf "fw: No arguments specified...\n" > /dev/stderr
	show_help
	exit 1
fi


# Keep options here
while [ $# -gt 0 ]
do
	case $1 in
		# Set the internet interface
		-w|--wan)
			shift
			if [ -z "$1" ] 
			then
				printf "fw: No argument specified for --wan flag\n" > /dev/stderr
				exit 1
			else 	
				WTMP=( `chop_at_colon "$1"` )
				if [ ${#WTMP} -eq 1 ]
				then
					WAN_IFACE="$1"
				elif [ ${#WTMP} -gt 1 ] 	
				then
					WAN_IFACE="${WTMP[0]}"
					IP_ADDRESS="${WTMP[1]}"
				fi
			fi
		;;

		# Set the DMZ interface
		-d|--dmz)
			shift
			if [ -z "$1" ] 
			then
				printf "fw: No argument specified for --dmz flag\n" > /dev/stderr
				exit 1
			else 	
				DTMP=( `chop_at_colon "$1"` )
				if [ ${#DTMP} -eq 1 ]
				then
					DMZ_IFACE="$1"
				elif [ ${#DTMP} -gt 1 ] 	
				then
					DMZ_IFACE="${DTMP[0]}"
					DMZ_ADDRESS="${DTMP[1]}"
				fi
			fi
		;;

		# Set the LAN interface
		-l|--lan)
			shift
			if [ -z "$1" ] 
			then
				printf "fw: No argument specified for --dmz flag\n" > /dev/stderr
				exit 1
			else 	
				LTMP=( `chop_at_colon "$1"` )
				if [ ${#LTMP} -eq 1 ]
				then
					LAN_IFACE="$1"
				elif [ ${#LTMP} -gt 1 ] 	
				then
					LAN_IFACE="${LTMP[0]}"
					LAN_ADDRESS="${LTMP[1]}"
				fi
			fi
		;;

		# Set the LAN interface
		-l|--lan)
			shift
			if [ -z "$1" ] 
			then
				printf "fw: No argument specified for --ssh flag\n" > /dev/stderr
				exit 1
			else
				ENABLE_SSH=1
				STMP=( `chop_at_colon "$1"` )
				if [ ${#STMP} -eq 1 ]
				then
					SSH_PORT="$1"
					SSH_ALLOWED_IP=
				elif [ ${#STMP} -gt 1 ] 	
				then
					SSH_PORT="${STMP[0]}"
					SSH_ALLOWED_IP="${STMP[1]}"
				fi
			fi
		;;

		# My IP address
		-i|--ip-address)
			shift
			IP_ADDRESS="$1"
		;;

		# Set subnet base
		-b|--subnet-base)
			shift
			SUBNET_BASE="$1"
		;;

		# Set subnet broadcast
		-c|--subnet-bcast)
			shift
			SUBNET_BCAST="$1"
		;;

		# Set an alternate logging path (for easy future access)
		-p|--log-path)
			shift
			LOG_PATH="$1"
		;;

		# Simply dump the options and stop
		-x|--dump)
			ACTION=$DO_DUMP
		;;

		# Adopt a deny by default policy
		--deny)
			ACTION=$DO_DEFAULT
		;;

		# TODO: OK. From experience, this sucks... so let's try something different.
		--stop)
			ACTION=$DO_STOP
		;;

		--single-home)
			ACTION=$DO_SINGLE_HOME
		;;

		--multi-home)
			ACTION=$DO_MULTI_HOME
		;;

		# Options for common port associations go here
		--http)
			ENABLE_HTTP=1	
		;;

		--https)
			ENABLE_HTTPS=1	
		;;

		-h|--help)
			show_help
			exit 0
		;;
	esac
	shift
done


# ...
if [ -z $ACTION ]
then 
	printf "fw: no action specified, nothing to do.\n" > /dev/stderr;
	exit 1;
fi


# Dump all the settings	
if [ $ACTION == $DO_DUMP ]
then
	dump_settings
	exit 0;
fi


# TODO: Check for root or elevated priveleges somehow, then die if not

# Go back to a deny-by-default state 
if [ $ACTION == $DO_DEFAULT ]
then
	set_defaults
	set_drop
	exit 0
fi


# Go back to a wide-open state
if [ $ACTION == $DO_STOP ]
then
	set_defaults
	exit 0
fi


# ...
if [ -z $IP_ADDRESS ]
then 
	printf "fw: no IP address specified for rule application.\n" > /dev/stderr;
	exit 1;
fi


# ...
if [ -z $WAN_IFACE ]
then 
	printf "fw: no WAN interface chosen.\n" > /dev/stderr;
	exit 1;
fi


# Go back to a default drop-everything state
if [ $ACTION == $DO_DEFAULT ]
then
	set_defaults	
	set_drop

# Run rules for a single home firewall
elif [ $ACTION == $DO_SINGLE_HOME ]
then
	set_defaults	
	set_drop
	set_state_tracking
	set_logdrop_spoof
	set_disallow_common_services
	set_allow_dns
	test ! -z $ENABLE_SSH && set_allow_incoming_ssh $SSH_PORT $SSH_ALLOWED_IP
	test ! -z $ENABLE_HTTP && set_allow_outgoing_generic_tcp 80
	test ! -z $ENABLE_HTTP && set_allow_incoming_generic_tcp 80
	test ! -z $ENABLE_HTTPS && set_allow_outgoing_generic_tcp 443
	test ! -z $ENABLE_HTTPS && set_allow_incoming_generic_tcp 443
	#set_log_all_incoming_dropped
	#set_log_all_outgoing_dropped
	exit 0;

# Run rules for a multi home firewall
elif [ $ACTION == $DO_MULTI_HOME ]
then
	printf "fw: multi home firewall not written yet.  Sorry.\n" > /dev/stderr;
	exit 0;

fi

exit 0;
