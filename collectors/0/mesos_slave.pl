#!/usr/bin/perl

use LWP::Simple;
use JSON;
use Data::Dumper;
use strict;
use warnings;

my $INTERVAL = 15;
my $MESOS_SLAVE_HOST="localhost";
my $MESOS_SLAVE_PORT="5051";
my $DOCKER="docker";

# 1: read metric names from file
# 0: filename is metric name
my $cgroup_files = {};
$cgroup_files->{'cpuacct'}->{'cpuacct.stat'}=1;
$cgroup_files->{'cpu'}->{'cpu.stat'}=1;
$cgroup_files->{'memory'}->{'memory.memsw.failcnt'}=0;
$cgroup_files->{'memory'}->{'memory.stat'}=1;
$cgroup_files->{'memory'}->{'memory.usage_in_bytes'}=0;
$cgroup_files->{'memory'}->{'memory.max_usage_in_bytes'}=0;


# flush after every write
$| = 1;
#-----
sub print_state {
   my $now = time();
   my $json_snapshot=get("http://$MESOS_SLAVE_HOST:$MESOS_SLAVE_PORT/metrics/snapshot") or die "Can't connect mesos slave";
   my $scalar_snapshot = JSON->new->utf8->decode($json_snapshot);
   foreach my $k (keys %{$scalar_snapshot})  {
      next if ($k =~ /^slave\/uptime_secs/);
      my $m = $k;
      $m  =~ s/\//./g;
      print "mesos.$m $now $scalar_snapshot->{$k}\n";
   }
}
sub process_statistics {
   my $config = $_[0];
   my $master_frameworks = $config->{'frameworks'};
   my $json_metrics=get("http://$MESOS_SLAVE_HOST:$MESOS_SLAVE_PORT/monitor/statistics.json") or die "Can't connect mesos slave";
   my $scalar_metrics = JSON->new->utf8->decode($json_metrics);
   my $now = time();
   for my $task (@$scalar_metrics) {
     my $stats = $task->{'statistics'};
     foreach my $m (keys %{$stats})  {
        my $k = $m;
        $m =~ s/\//./g;
        my $fw = $master_frameworks->{$task->{'framework_id'}} || "orphaned";
        $config->{'tasks'}->{$task->{'executor_id'}}->{'tags'} = "framework=$fw";
        if ($fw eq "marathon" ) {
            (my $group, my $container) = split(/\./,$task->{'executor_id'});
            my @group_hier = split(/_/, $group);
            if (@group_hier == 1 ) {
                $config->{'tasks'}->{$task->{'executor_id'}}->{'tags'} .= " marathon_app=$group_hier[0]";
            } else {
               $config->{'tasks'}->{$task->{'executor_id'}}->{'tags'} .= " marathon_group=$group_hier[0]";
               shift @group_hier;
               $config->{'tasks'}->{$task->{'executor_id'}}->{'tags'} .= " marathon_app=" . join("_",@group_hier);
            }
        } else {
           $config->{'tasks'}->{$task->{'executor_id'}}->{'tags'} =""
        }
        $config->{'tasks'}->{$task->{'executor_id'}}->{'framework_id'}=$task->{'framework_id'};
        print "mesos.slave.monitor.stats.$k $now $stats->{$k} task_id=$task->{'executor_id'} framework_id=$task->{'framework_id'}";
        print " $config->{'tasks'}->{$task->{'executor_id'}}->{'tags'}";
        print "\n";
     }
  } 
  return $config;
}

sub get_config {
    my $json_mesos_state = get("http://$MESOS_SLAVE_HOST:$MESOS_SLAVE_PORT/state.json") or die  "Can't connect mesos slave";
    my $scalar_mesos_state =  JSON->new->utf8->decode($json_mesos_state);
    my $config = {};
    $config->{'master_url'} = "http://" . $scalar_mesos_state->{'master_hostname'} . ":5050";
    $config->{'cgroups_hierarchy'} = $scalar_mesos_state->{flags}->{cgroups_hierarchy};
    $config->{'cgroups_root'} = $scalar_mesos_state->{flags}->{cgroups_root};

    my $json_master_state = get($config->{'master_url'} . "/state.json");
    my $scalar_master_state = JSON->new->utf8->decode($json_master_state);

    foreach my $mf (@{$scalar_master_state->{frameworks}}) {
        if ($mf->{name} =~ m/^([^-]+)-(.*)/ ) {
           $config->{'frameworks'}->{$mf->{id}} = $1;
        } else {
           next
        }
    }
    # 
    my @frameworks = @{$scalar_mesos_state->{'frameworks'}};
    foreach my $f (@frameworks) {
      my @tasks = @{$f->{'executors'}};
      foreach my $t (@tasks) {
      $config->{'tasks'}->{$t->{'id'}}->{'container'}=$t->{'container'};
      # may be replaced by docker;
      $config->{'tasks'}->{$t->{'id'}}->{'containerizer'}="mesos";
      $config->{'containers'}->{$t->{'container'}}->{'task_id'}=$t->{'id'};
     }
    }
    return $config;
}

# replace mesos container by docker's one
sub get_docker_info {
    my $config = $_[0];
    open(DOCKER,"$DOCKER ps -q|");
    while(my $line=<DOCKER>) {
        chomp($line);
        my $docker_json=`$DOCKER inspect $line`;
        my @scalar_docker = JSON->new->utf8->decode($docker_json) or die "oh crap";
        my @s = shift @{$scalar_docker[0]};
        my $tmp_id = my $tmp_mesos = 0;
        foreach my $a (@s) {
           $a->{Name} =~ s/\/mesos-//;
             my $id = $config->{'containers'}->{$a->{Name}}->{'task_id'};
             $config->{'tasks'}->{$id}->{'container'}=$a->{Id};
             $config->{'tasks'}->{$id}->{'containerizer'}='docker';
       }
    }
    return $config;
}

sub print_cgroup_stats {
    my $config = $_[0];
    my $now = time();
    foreach my $t (keys %{$config->{'tasks'}}) {
       foreach my $k (keys %{$cgroup_files}) {
         my $type = $cgroup_files->{$k};
         foreach my $kk (keys %{$type}) {
             my $path = "$config->{'cgroups_hierarchy'}/$k/";
            if ($config->{'tasks'}->{$t}->{'containerizer'} eq 'docker') {
                $path .= "docker";
            } else {
                $path .= $config->{cgroups_root};
            }
            next unless open(FH, $path . "/" . $config->{'tasks'}->{$t}->{'container'} . "/$kk");
            if ($type->{$kk} == "0") {
                my $v = <FH>;
                chomp($v);
                my $kkk = $kk =~ s/$k\.//g;
                print "mesos.slave.monitor.cgroup.$k.$kk $now $v task_id=$t framework_id=$config->{'tasks'}->{$t}->{'framework_id'}";
                print " $config->{'tasks'}->{$t}->{'tags'}";
                print "\n";
            } else {
                 while(my $line=<FH>) {
                    chomp($line);
                    my ($kkk, $v)=split(/\s+/,$line);
                    print "mesos.slave.monitor.cgroup.$k.$kkk $now $v  task_id=$t framework_id=$config->{'tasks'}->{$t}->{'framework_id'}";
                    print " $config->{'tasks'}->{$t}->{'tags'}";
                    print "\n";
                 }
            }                                                                                                        
            close(FH);
         }
       }
   } 
}

#----
while (1){
   print_state();
   my $now = time();
   my $c=get_config;
   $c = process_statistics($c);
   $c = get_docker_info($c);
   print_cgroup_stats($c);
   sleep $INTERVAL;
}

