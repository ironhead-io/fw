# Install this script and set up other things
USER=root
GROUP=root
PREFIX=/usr/local
SCRIPT=fw
IPTABLES=/sbin/iptables

# list : List all the targets and what they do
list:
	@printf 'Available options are:\n'
	@sed -n '/^# / { s/# //; 1d; p; }' Makefile | awk -F ':' '{ printf "  %-20s - %s\n", $$1, $$2 }'


# envconfig : Build a permanent firewall configuration using environment variables
envconfig:
	@sed '{ s|__PREFIX__|$(PREFIX)|; s|__INTERFACE__|$(INTERFACE)|; s|__SSH_PORT__|$(SSH_PORT)|; s|__TCP_PORTS__|$(TCP_PORTS)| ;s|__IP_ADDRESS__|$(IP_ADDRESS)| ; }' systemd/etc.systemd.system.fw.service > systemd/.config


# makeconfig : Build a permanent firewall configuration using Makefile overrides
makeconfig:
	@sed '{ s|__PREFIX__|$(PREFIX)|; s|__SSH_PORT__|$(SSH_PORT)| ; s|__TCP_PORTS__|$(TCP_PORTS)| ;s|__IP_ADDRESS__|$(IP_ADDRESS)| ; }' systemd/etc.systemd.system.fw.service > systemd/.config


# menuconfig : Build a permanent firewall configuration using an interactive script
menuconfig:
	./interactive.sh -f systemd/.config	


# install : Install to $PREFIX
install: check
install:
	test -d $(PREFIX)/bin || mkdir -p $(PREFIX)/bin/
	cp $(SCRIPT).sh $(PREFIX)/bin/$(SCRIPT)
	chown $(USER):$(GROUP) $(PREFIX)/bin/$(SCRIPT)
	chmod 544 $(PREFIX)/bin/$(SCRIPT) 


# systemd : Enable firewall to run at boot on systemd capable systems
systemd:
	cp systemd/.config /etc/systemd/system/fw.service	


# sysv : Enable firewall to run at boot on SysV capable systems
sysv:
	printf '' >/dev/null


# pkg : Something with packages
pkg:
	cd ../ && tar czf firewall.tgz firewall/


# check : Checks for iptables
check:
	@test -x $(IPTABLES) && echo "IpTables is present." || { \
		printf "IPTables not installed, exiting.\n" > /dev/stderr; \
		exit 5; \
	}

