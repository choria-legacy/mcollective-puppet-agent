metadata    :name        => "puppet_tags",
            :description => "Validates that a comma seperated list of tags are valid Puppet class names",
            :author      => "R.I.Pienaar <rip@devco.net>",
            :license     => "ASL 2.0",
            :version     => "1.0",
            :url         => "http://devco.net/",
            :timeout     => 1

usage <<-EOU
Puppet tags can be a comma seperated list of valid class names, for details
about valid class names please see the puppet_variable validator documentation.

An example of 2 tags would be:

    apache,mysql::master
EOU
