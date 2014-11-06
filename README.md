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

Per default, these collectors grabs metric on localhost:5050 for master and localhost:5051 for slave
You can change thoses values directly in perl script (*mesos_master.pl* and *mesos_slave.pl*)


