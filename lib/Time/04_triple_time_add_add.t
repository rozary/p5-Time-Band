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
use Test::Base::Less;
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

  my $s_t3 = localtime->from_mysql_datetime($block->start_time3);
  my $e_t3 = localtime->from_mysql_datetime($block->end_time3);

  my $expected = $block->expected;
  my $tb = Time::Band->new(start=>$s_t1,end=>$e_t1);
  $tb->add($s_t2,$e_t2);
  $tb->add($s_t3,$e_t3);
  my $res = $tb->result;

  print scalar @$res;
  print "\n";
  is_deeply($res,$expected,$block->name);
}

done_testing;

__DATA__

=== triple time A A space B B space C C
--- start_time1: 2013-07-01 10:00:00
--- end_time1: 2013-07-01 13:00:00
--- start_time2: 2013-07-01 14:00:00
--- end_time2: 2013-07-01 16:00:00
--- start_time3: 2013-07-01 17:00:00
--- end_time3: 2013-07-01 23:00:00
--- expected
use Time::Piece;
my $s_t1 = localtime->strptime("2013-07-01 10:00:00","%Y-%m-%d %T");
my $e_t1 = localtime->strptime("2013-07-01 13:00:00","%Y-%m-%d %T");
my $s_t2 = localtime->strptime("2013-07-01 14:00:00","%Y-%m-%d %T");
my $e_t2 = localtime->strptime("2013-07-01 16:00:00","%Y-%m-%d %T");
my $s_t3 = localtime->strptime("2013-07-01 17:00:00","%Y-%m-%d %T");
my $e_t3 = localtime->strptime("2013-07-01 23:00:00","%Y-%m-%d %T");
$s_t1->epoch;
$e_t1->epoch;
$s_t2->epoch;
$e_t2->epoch;
$s_t3->epoch;
$e_t3->epoch;
[
  [
    $s_t1,
    $e_t1,
  ],
  [
    $s_t2,
    $e_t2,
  ],
  [
    $s_t3,
    $e_t3,
  ],
]

=== triple time A A B B space C C
--- start_time1: 2013-07-01 10:00:00
--- end_time1: 2013-07-01 14:00:00
--- start_time2: 2013-07-01 14:00:00
--- end_time2: 2013-07-01 16:00:00
--- start_time3: 2013-07-01 17:00:00
--- end_time3: 2013-07-01 23:00:00
--- expected
use Time::Piece;
my $s_t1 = localtime->strptime("2013-07-01 10:00:00","%Y-%m-%d %T");
my $e_t1 = localtime->strptime("2013-07-01 16:00:00","%Y-%m-%d %T");
my $s_t2 = localtime->strptime("2013-07-01 17:00:00","%Y-%m-%d %T");
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
