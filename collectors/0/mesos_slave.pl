#!/usr/bin/perl

use LWP::Simple;
use JSON;
use strict;
use warnings;

my $INTERVAL = 15;
my $MESOS_SLAVE_HOST="localhost";
my $MESOS_SLAVE_PORT="5051";

# 1: read metric names from file
# 0: filename is metric name
my $cgroup_files = ();
$cgroup_files->{'cpuacct'}->{'cpuacct.stat'};
$cgroup_files->{'cpu'}->{'cpu.stat'}=1;
$cgroup_files->{'memory'}->{'memory.memsw.failcnt'}=0;
$cgroup_files->{'memory'}->{'memory.stat'}=1;
$cgroup_files->{'memory'}->{'memory.usage_in_bytes'}=0;
$cgroup_files->{'memory'}->{'memory.max_usage_in_bytes'}=0;


# flush after every write
$| = 1;

while (1){
   my $json_metrics=get("http://$MESOS_SLAVE_HOST:$MESOS_SLAVE_PORT/metrics/snapshot") or die "Can't connect mesos slave";
   my $now = time();
   my $scalar_metrics = JSON->new->utf8->decode($json_metrics);
   foreach my $m (keys %{$scalar_metrics})  {
      my $k = $m;
      $m =~ s/\//./g;
      print "mesos.$m $now $scalar_metrics->{$k}\n";
   }
   my $json_mesos_state = get("http://$MESOS_SLAVE_HOST:$MESOS_SLAVE_PORT/state.json") or die  "Can't connect mesos slave";
   my $scalar_mesos_state =  JSON->new->utf8->decode($json_mesos_state);
   $json_metrics=get("http://$MESOS_SLAVE_HOST:$MESOS_SLAVE_PORT/monitor/statistics.json") or die "Can't connect mesos slave";
   $now = time();
   $scalar_metrics = JSON->new->utf8->decode($json_metrics);
   for my $task (@$scalar_metrics) {
     my $stats = $task->{'statistics'};
     foreach my $m (keys %{$stats})  {
        my $k = $m;
        $m =~ s/\//./g;
        print "mesos.slave.monitor.stats.$k $now $stats->{$k} task_id=$task->{'executor_id'} framework_id=$task->{'framework_id'} \n";
     }
     my @frameworks = @{$scalar_mesos_state->{'frameworks'}};
     foreach my $f (@frameworks) {
        next unless $f->{'id'} eq $task->{'framework_id'};
        my @tasks = @{$f->{'executors'}};
        foreach my $t (@tasks) {
             next unless $t->{'id'} eq $task->{'executor_id'};
             foreach my $k (keys %{$cgroup_files}) {
                  my $tmp = $cgroup_files->{$k};
                  foreach my $kk (keys %{$tmp}) {
                      next unless open(FH, $scalar_mesos_state->{flags}->{cgroups_hierarchy} . "/$k/" . $scalar_mesos_state->{flags}->{cgroups_root}. "/" . $t->{'container'} . "/$kk");
                      if ($tmp->{$kk} == "0") {
                          my $v = <FH>;
                          chomp($v);
                          my $kkk = $kk =~ s/$k\.//g;
                          print "mesos.slave.monitor.cgroup.$k.$kk $now $v task_id=$task->{'executor_id'} framework_id=$task->{'framework_id'}\n";
                      } else {
                        while(my $line=<FH>) {
                           chomp($line);
                           my ($kkk, $v)=split(/\s+/,$line);
                           print "mesos.slave.monitor.cgroup.$k.$kkk $now $v task_id=$task->{'executor_id'} framework_id=$task->{'framework_id'}\n";
                        }
                     }
                }
             }
         }
       }
     }
   sleep $INTERVAL;
}

