metadata    :name        => "puppet_resource",
            :description => "Validates the validity of a Puppet resource type and name",
            :author      => "R.I.Pienaar <rip@devco.net>",
            :license     => "ASL 2.0",
            :version     => "1.0",
            :url         => "http://devco.net/",
            :timeout     => 1

usage <<-EOU
Valid resource names are in the form: resource_type[resource_name].

Resource types has to validate against the regular expression:

   [a-zA-Z0-9_]+

While resource names might be any character.
EOU
