#!/usr/bin/perl

use LWP::Simple;
use JSON;
use strict;
use warnings;

my $INTERVAL = 15;
my $MESOS_SLAVE_HOST="localhost";
my $MESOS_SLAVE_PORT="5051";

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
   sleep $INTERVAL;
}

