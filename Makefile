MESOS= collectors/0/mesos_slave.pl collectors/0/mesos_master.pl
COLLECTORS_DIR=/dev/null

all: mesos
mesos: mesos_master mesos_slave

mesos_master:
	install -m 755 collectors/0/mesos_master.pl $(COLLECTORS_DIR)/0

mesos_slave:
	install -m 755 collectors/0/mesos_slave.pl $(COLLECTORS_DIR)/0
