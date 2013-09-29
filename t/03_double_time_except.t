#!/usr/bin/perl

use 5.15.9;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Time::Piece;
use Time::Piece::MySQL;
use Try::Tiny;
use Test::More;
use Test::Difflet qw/is_deeply/;
#use Test::Base;
use Test::Base::Less;
use lib "./";
use Band;

plan tests=>8;

filters {
  expected=>["eval"],
};

foreach my $block (blocks()) {
  my $s_t1 = localtime->from_mysql_datetime($block->start_time1);
  my $e_t1 = localtime->from_mysql_datetime($block->end_time1);

  my $s_t2 = localtime->from_mysql_datetime($block->start_time2);
  my $e_t2 = localtime->from_mysql_datetime($block->end_time2);

  my $expected = $block->expected;
  my $tb = Time::Band->new(start=>$s_t1,end=>$e_t1);
  $tb->except($s_t2,$e_t2);
  my $res = $tb->result;

  is_deeply($res,$expected,$block->name);
}

done_testing;

__DATA__

=== double time A A space B B
--- start_time1: 2013-07-01 10:00:00
--- end_time1: 2013-07-01 15:00:00
--- start_time2: 2013-07-01 16:00:00
--- end_time2: 2013-07-01 23:00:00
--- expected
use Time::Piece;
my $s_t1 = localtime->strptime("2013-07-01 10:00:00","%Y-%m-%d %T");
my $e_t1 = localtime->strptime("2013-07-01 15:00:00","%Y-%m-%d %T");
$s_t1->epoch;
$e_t1->epoch;
[
  [
    $s_t1,
    $e_t1,
  ],
]

=== double time A A B B
--- start_time1: 2013-07-01 10:00:00
--- end_time1: 2013-07-01 15:00:00
--- start_time2: 2013-07-01 15:00:00
--- end_time2: 2013-07-01 23:00:00
--- expected
use Time::Piece;
my $s_t1 = localtime->strptime("2013-07-01 10:00:00","%Y-%m-%d %T");
my $e_t2 = localtime->strptime("2013-07-01 15:00:00","%Y-%m-%d %T");
$s_t1->epoch;
$e_t2->epoch;
[
  [
    $s_t1,
    $e_t2,
  ]
]

=== double time B B A A 
--- start_time1: 2013-07-01 15:00:00
--- end_time1: 2013-07-01 23:00:00
--- start_time2: 2013-07-01 10:00:00
--- end_time2: 2013-07-01 15:00:00
--- expected
use Time::Piece;
my $s_t1 = localtime->strptime("2013-07-01 10:00:00","%Y-%m-%d %T");
my $e_t2 = localtime->strptime("2013-07-01 15:00:00","%Y-%m-%d %T");
$s_t1->epoch;
$e_t2->epoch;
[
  [
    $s_t1,
    $e_t2,
  ]
]

=== double time B B space A A
--- start_time1: 2013-07-01 16:00:00
--- end_time1: 2013-07-01 23:00:00
--- start_time2: 2013-07-01 10:00:00
--- end_time2: 2013-07-01 15:00:00
--- expected
use Time::Piece;
my $s_t2 = localtime->strptime("2013-07-01 16:00:00","%Y-%m-%d %T");
my $e_t2 = localtime->strptime("2013-07-01 23:00:00","%Y-%m-%d %T");
$s_t2->epoch;
$e_t2->epoch;
[
  [
    $s_t2,
    $e_t2,
  ]
]

=== double time A B B A
--- start_time1: 2013-07-01 10:00:00
--- end_time1: 2013-07-01 23:00:00
--- start_time2: 2013-07-01 14:00:00
--- end_time2: 2013-07-01 15:00:00
--- expected
use Time::Piece;
my $s_t1 = localtime->strptime("2013-07-01 10:00:00","%Y-%m-%d %T");
my $e_t1 = localtime->strptime("2013-07-01 14:00:00","%Y-%m-%d %T");
my $s_t2 = localtime->strptime("2013-07-01 15:00:00","%Y-%m-%d %T");
my $e_t2 = localtime->strptime("2013-07-01 23:00:00","%Y-%m-%d %T");
$s_t1->epoch;
$e_t1->epoch;
$s_t2->epoch;
$e_t2->epoch;
[
  [
    $s_t1,
    $e_t1,
  ],
  [
    $s_t2,
    $e_t2,
  ],
]

=== double time B A A B
--- start_time1: 2013-07-01 14:00:00
--- end_time1: 2013-07-01 15:00:00
--- start_time2: 2013-07-01 10:00:00
--- end_time2: 2013-07-01 23:00:00
--- expected: []

=== double time A B A B
--- start_time1: 2013-07-01 10:00:00
--- end_time1: 2013-07-01 15:00:00
--- start_time2: 2013-07-01 14:00:00
--- end_time2: 2013-07-01 23:00:00
--- expected
use Time::Piece;
my $s_t1 = localtime->strptime("2013-07-01 10:00:00","%Y-%m-%d %T");
my $e_t1 = localtime->strptime("2013-07-01 14:00:00","%Y-%m-%d %T");
$s_t1->epoch;
$e_t1->epoch;
[
  [
    $s_t1,
    $e_t1,
  ],
]

=== double time B A B A
--- start_time1: 2013-07-01 14:00:00
--- end_time1: 2013-07-01 23:00:00
--- start_time2: 2013-07-01 10:00:00
--- end_time2: 2013-07-01 15:00:00
--- expected
use Time::Piece;
my $s_t1 = localtime->strptime("2013-07-01 15:00:00","%Y-%m-%d %T");
my $e_t1 = localtime->strptime("2013-07-01 23:00:00","%Y-%m-%d %T");
$s_t1->epoch;
$e_t1->epoch;
[
  [
    $s_t1,
    $e_t1,
  ],
]
