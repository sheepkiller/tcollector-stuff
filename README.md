tcollector-stuff
================

Custom collectors for OpenTSDB
Installation (not yet)
------
```sh
mkdir ~/tmp/dist && ~/tmp/dist
git clone https://github.com/sheepkiller/tcollectors-stuff.git
cd tcollectors-stuff
make 

```

Mesos [perl]
-----
module dependencies
* libwww-perl (LWP::Simple)
* JSON

Per default, these collectors grab metrics via http://localhost:5050 for master and http://localhost:5051 for slave.
You can change those values directly in perl scripts (*mesos_master.pl* and *mesos_slave.pl*).

If you use cgroup/* containerizer, support is **experimental**.

