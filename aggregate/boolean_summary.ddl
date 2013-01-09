metadata :name => "boolean_summary",
         :description => "Aggregate function that will transform true/false values into predefined strings.",
         :author => "P. Loubser <pieter.loubser@puppetlabs.com>",
         :license => "ASL 2.0",
         :version => "1.0",
         :url => "http://projects.puppetlabs.com/projects/mcollective-plugins/wiki",
         :timeout => 1

usage <<-EOU
An Aggregate plugin that allows you to summarize boolean results and supply custom
titles instead of just 'true' and 'false' the normal summary plugin would provide

   aggregate boolean_summary(:alive, {:true => "Alive", :false => "Dead" })

When displayed this will show:

Summary of Alive:

   Dead = 1
   Alive = 1
EOU
