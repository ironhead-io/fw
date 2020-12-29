#!/bin/bash -

IPT=iptables

$IPT -t nat -A POSTROUTING -o $LAN_IP -j SNAT
