#!/usr/bin/perl

BEGIN {
  use Test::MockTime qw/set_absolute_time/;
  set_absolute_time('2012-01-08T00:00:00Z');
}

use strict;
use warnings;
use Data::Dumper;

use lib "lib/";
use Test::More tests => 50;
use Time::Piece;
use Time::Band;

my $t1 = localtime();
my $t2 = localtime() + 1200;

my $band = Time::Band->new(start=>$t1,end=>$t2);

my $t3 = localtime() + 60;
my $t4 = localtime() + 180;

$band->add_except($t3,$t4);

my $result = [@{$band->result}];
my $r = shift @$result;
is $r->[0]->datetime, "2012-01-08T09:00:00","start";
is $r->[1]->datetime, "2012-01-08T09:01:00","end";
is scalar @$result , 1, "1 band ok";

$r = shift @$result;
is $r->[0]->datetime, "2012-01-08T09:03:00","start";
is $r->[1]->datetime, "2012-01-08T09:20:00","end";
is scalar @$result , 0, "no band ok";

my $band2 = Time::Band->new(start=>$t1,end=>$t2);
$band2->add_except(localtime() - 60,localtime() + 180);
$result = [@{$band2->result}];
$r = shift @$result;
is $r->[0]->datetime, "2012-01-08T09:03:00", "start";
is $r->[1]->datetime, "2012-01-08T09:20:00", "start";
is scalar @$result , 0, "no band ok";

$band2->add_except(localtime() +240,localtime() +540);
$result = [@{$band2->result}];
is scalar @$result , 2, "2 band ok";
$r = shift @$result;
is $r->[0]->datetime, "2012-01-08T09:03:00", "start";
is $r->[1]->datetime, "2012-01-08T09:04:00", "start";
is scalar @$result , 1, "1 band ok";

$r = shift @$result;
is $r->[0]->datetime, "2012-01-08T09:09:00", "start";
is $r->[1]->datetime, "2012-01-08T09:20:00", "start";
is scalar @$result , 0, "0 band ok";

$band2->add_except(localtime() +600,localtime() + 1200);
$result = [@{$band2->result}];
is scalar @$result , 2, "2 band ok";
$r = shift @$result;
is $r->[0]->datetime, "2012-01-08T09:03:00", "start";
is $r->[1]->datetime, "2012-01-08T09:04:00", "start";
is scalar @$result , 1, "1 band ok";

$r = shift @$result;
is $r->[0]->datetime, "2012-01-08T09:09:00", "start";
is $r->[1]->datetime, "2012-01-08T09:10:00", "start";
is scalar @$result , 0, "0 band ok";



my $band3 = Time::Band->new(start=>$t1,end=>$t2);
$band3->add_except(localtime() + 60,localtime() + 1200);
$result = [@{$band3->result}];
$r = shift @$result;
is $r->[0]->datetime, "2012-01-08T09:00:00", "start";
is $r->[1]->datetime, "2012-01-08T09:01:00", "end";
is scalar @$result , 0, "no band ok";


my $band4 = Time::Band->new(start=>$t1,end=>$t2);
$band4->add_except(localtime() + 60,localtime() + 120);
$band4->add_except(localtime() + 120,localtime() + 360);
my $result = [@{$band4->result}];
my $r = shift @$result;
is $r->[0]->datetime, "2012-01-08T09:00:00", "start";
is $r->[1]->datetime, "2012-01-08T09:01:00", "end";
$r = shift @$result;
is $r->[0]->datetime, "2012-01-08T09:06:00", "start";
is $r->[1]->datetime, "2012-01-08T09:20:00", "end";
is scalar @$result , 0, "no band ok";


1;
