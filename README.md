# fw  

A simple firewall script.


## Installation

`fw` uses `make` to install the firewall script.  Simply running `make` will 
output a list of possible targets.


The most pertinent targets are:

`make install` - Which installs the firewall.

`make systemd` - Which enables the firewall to run via systemd.

`make sysv` - Which enables the firewall to run on SysV init-capable systems.

`make check` - Checks for iptables, a necessary dependency.


## Usage 

Options for using `fw` are as follows.

<pre>
-w, --wan <arg:[ip]>      Specify the WAN interface (& an optional IP address)
-d, --dmz <arg:[ip]>      Specify the DMZ interface (& an optional IP address)
-l, --lan <arg:[ip]>      Specify the LAN interface (& an optional IP address)
-a, --ssh <arg:[ip]>      Specify a port (& an optional IP address to listen 
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
-t, --tcp <arg1...argN>   Enable one or many generic TCP ports to listen for 
                          connections.
-h, --help                Show help.
</pre>


### Quickstart

A typical invocation of `fw` will look something like:

<pre>
$ fw -w eno1:99.99.88.111 --ssh 22 --single-home
</pre>

Running the above code will run firewall rules using the interface 'eno1' as
the WAN interface.  It will also poke a hole for SSH access at port 22.


