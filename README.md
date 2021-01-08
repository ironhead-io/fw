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
-w, --wan &lt;arg:[ip]&gt;     Specify the WAN interface (& an optional IP address)
-d, --dmz &lt;arg:[ip]&gt;     Specify the DMZ interface (& an optional IP address)
-l, --lan &lt;arg:[ip]&gt;     Specify the LAN interface (& an optional IP address)
-a, --ssh &lt;arg:[ip]&gt;     Specify a port (& an optional IP address to listen 
                          out for) for SSH connections
-i, --ip-address &lt;arg&gt;   Specify an IP for the WAN interface 
                          (if DMZ or LAN are not specified)
-b, --subnet-base &lt;arg&gt;  Specify a subnet base
-c, --subnet-bcast &lt;arg&gt; Specify a subnet broadcast
-p, --log-path &lt;arg&gt;     Specify an alternate log path for firewall messages 

Actions:
-x, --dump                     Dump the currently loaded variables 
    --deny                     Flush any rules and go back to deny-by-default policy.
    --stop                     Totally stop the firewall.
    --single-home              Start a single home firewall.
    --multi-home               Start a multi home firewall.
-t, --tcp &lt;arg1...argN&gt;  Enable one or many generic TCP ports to listen for 
                               connections.
-h, --help                     Show help.
</pre>


### Quickstart / Recipes 

A typical invocation of `fw` will look something like:

<pre>
$ fw -w eno1:99.99.88.111 --ssh 22 --single-home
</pre>

Running the above code will run firewall rules using the interface 'eno1' as
the WAN interface.  It will also poke a hole for SSH access at port 22.


If a web server (or other simple TCP service) is needed, the same invocation
can be used with an additional `--tcp` argument. 

<pre>
$ fw -w eno1:99.99.88.111 --ssh 22 --single-home --tcp 80
</pre>

The `--tcp` option will support opening multiple <i>bi-directional</i> ports
at once.  

<pre>
$ fw -w eno1:99.99.88.111 --ssh 22 --single-home --tcp 80 443 1222
</pre>

Note that connections both coming from inside and outside of the firewall will 
be able to access services on the ports specified.
