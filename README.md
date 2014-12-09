tcollector-stuff
================

Custom collectors for OpenTSDB
Installation (required GNU make - WARNING crappy Makefile)
------
```sh
mkdir ~/tmp/dist && ~/tmp/dist
git clone https://github.com/sheepkiller/tcollectors-stuff.git
cd tcollectors-stuff
# to install mesos slave collector
make -e COLLECTORS_DIR=~/tmp mesos_slave
# to install all mesos collectors
make -e COLLECTORS_DIR=~/tmp mesos
# to install all collectors
make -e COLLECTORS_DIR=~/tmp 

```

Mesos [perl]
-----
module dependencies
* libwww-perl (LWP::Simple)
* JSON

Per default, these collectors grab metrics via http://localhost:5050 for master and http://localhost:5051 for slave.
You can change those values directly in perl scripts (*mesos_master.pl* and *mesos_slave.pl*).
5 tags max, to support host,rackid,dc.
Metrics
* master/slave snapshot
* on slave: container statitics + cgroup if available (mesos + docker)
* framework name resolution (Not tested on large cluster)
* dynamically tag marathon apps/groups ("/play" gives "marathon_app=play", and /presto/meta/discovery gives "marathn_group=presto" and "marathon_app=meta_discovery")
