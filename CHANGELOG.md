# Changelog

Change history for mcollective-puppet

## 1.9.2

* Refactor `Puppetrunner#run_hosts` to remove a infinite loop (MCOP-351)
* Add more log messages at debug (MCOP-352)

## 1.9.1

Released 2014-10-23

* Extract `make_status` to fix some code flows in `mco runall` (MCOP-330)

## 1.9.0

Released 2014-10-21

* Track nodes that did not respond to the puppet.status action during runall (MCOP-309)
* Expose `plugin.puppet.signal_daemon` configuration option (PR#37, MCOP-310)

## 1.8.1

Released 2014-09-11

* Handle slow/no response from agents when told to run (MCOP-290)

## 1.8.0

Released 2014-08-20

* Correctly honor concurrency argument of runall (MCOP-20)
* Allow for validation of IPs as named (MCOP-13)
* Change foreground run parameters to allow --splay to work again
  (PR#17 hblock)
* Refactored some internals to make tests less order-dependent
  (MCOP-12)
* Switched to using Process#spawn on Windows systems to correctly
  respect PATH (MCOP-52)
* Add the ability to whitelist and blacklist resources based on
  resource name (PR#28 tczekajlo)
* Default data plugin values to avoid exceptions around returning nil
  (MCOP-47)
* Make runall work with compound filters (MCOP-67)

## 1.7.2

Released 2014-04-25

* Fix `mco puppet` backtrace when no results are returned (MCOP-26)
* Remove implicit requirement on puppet 3.5.x (MCOP-25)

## 1.7.1

Released 2014-04-23

* Fix puppet initialization issue that broke mcollective-server-agent (MCOP-23)

## 1.7.0

Released 2014-02-20

* Fully qualified uses of Process to avoid clashes with process agent (PR#13)
* Fix `--no-noop` and `--no-splay` under MCollective 2.3.x and 2.4.x (MCOP-5)
* Change method of running puppet agent to double-fork a foregroung run (MCO-31)

## 1.6.2

Released 2013-12-04

* Change noop to no-op for frontend text (MCO-28)

## 1.6.1

Released 2013-10-15

* Make `--force` option correct imply `--no-splay` (22860)

## 1.6.0

Released 2013-06-08

* Support controlling Puppet on Windows (19541)
* Increase the DDL timeout to better handle slower servers where
  puppet start is slow (20618)

## 1.5.1

Released 2013-03-01

* Add a `--rerun` option to the runall command that loops over the
  nodes forever (19541)

## 1.5.0

Released 2013-02-22

* Add the `mco puppet resource` command (12712)
* Correctly handle mixed case resource names when determining if a
  resource is managed (19384)
* Improve error message when a resource does not pass validation (19384)

## 1.4.1

Released 2013-02-16

* Provide type distribution data in the `last_run_summary` action (19284)

## 1.4.0

Released 2013-02-08

* Add support for `--ignoreschedules` (19106)
* Add `--tags` as an alias to `--tag` (19137)

## 1.3.0

Released 2013-02-06

* Support custom puppet config locations using
  `plugin.puppet.config` (19094)

## 1.2.1

Released 2013-02-01

* Prevent uneeded warning log messages each time status is
  requested (18956)

## 1.2.0

Released 2013-01-17

* Add sparkline based summary stat graphs for the entire estate (18704)


## 1.1.1

Released 2013-01-16

* Add the `--runall` command (18664)

## 1.1.0

Released 2013-01-09

* Report idling time and check if the agent is disabled before
  attempting to run (15472)
* Add the `mco puppet` application (15472)
