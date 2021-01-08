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


# install : Install to $PREFIX
install: check
install:
	test -d $(PREFIX)/bin || mkdir -p $(PREFIX)/bin/
	cp $(SCRIPT).sh $(PREFIX)/bin/$(SCRIPT)
	chown $(USER):$(GROUP) $(PREFIX)/bin/$(SCRIPT)
	chmod 544 $(PREFIX)/bin/$(SCRIPT) 


# systemd : Enable firewall to run at boot on systemd capable systems
systemd:
	printf '' >/dev/null


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



