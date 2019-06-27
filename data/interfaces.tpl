# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# Management network interface
allow-hotplug eth0
iface eth0 inet static
	address IP1/24
	gateway GW

# Storage network interface
allow-hotplug eth1
iface eth1 inet static
	address IP2/24
