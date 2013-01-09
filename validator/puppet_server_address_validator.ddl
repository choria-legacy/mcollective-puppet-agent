metadata    :name        => "puppet_server_address",
            :description => "Validates that a string is a valid Puppet Server and Port for the Puppet agent",
            :author      => "R.I.Pienaar <rip@devco.net>",
            :license     => "ASL 2.0",
            :version     => "1.0",
            :url         => "http://devco.net/",
            :timeout     => 1

usage <<-EOU
The Puppet server address can be just a hostname or a hostname and port combination.

To specify just a hostname:

   puppet.example.com

...and to specify a port too:

   puppet.example.com:8080

You cannot just specify a port on it's own
EOU
