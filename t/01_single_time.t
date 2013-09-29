#!/usr/bin/perl

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

plan tests => 8;

filters {
  expected=>["eval"],
  expected_except=>["eval"],
};

foreach my $block (blocks()) {
  my $s_t1 = localtime->from_mysql_datetime($block->start_time);
  my $e_t1 = localtime->from_mysql_datetime($block->end_time);

  my $expected = $block->expected;
  my $tb = Time::Band->new(start=>$s_t1,end=>$e_t1);
  my $res = $tb->result;
  is_deeply($expected,$res,$block->name);


  $tb = Time::Band->new();
  $tb->add($s_t1,$e_t1);
  $res = $tb->result;
  foreach my $e (@$expected) {
    foreach my $r (@$res) {
      is($e->[0],$r->[0],sprintf("%s %s add",$block->name,$r->[0]->datetime));
      is($e->[1],$r->[1],sprintf("%s %s add",$block->name,$r->[1]->datetime));
    }
  }

  $expected = $block->expected_except;
  $tb = Time::Band->new();
  $tb->except($s_t1,$e_t1);
  $res = $tb->result;
  is_deeply($expected,$res,"except");
}


done_testing;

__DATA__

=== single time
--- start_time: 2013-07-01 10:00:00
--- end_time: 2013-07-01 23:00:00
--- expected
use Time::Piece;
my $s_t = localtime->strptime("2013-07-01 10:00:00","%Y-%m-%d %T");
my $e_t = localtime->strptime("2013-07-01 23:00:00","%Y-%m-%d %T");
$s_t->epoch;
$e_t->epoch;
[
  [
    $s_t,
    $e_t,
    1,1,1
  ]
]
--- expected_except: []

=== over_time
--- start_time: 2013-07-01 23:00:00
--- end_time: 2013-07-02 23:00:00
--- expected
use Time::Piece;
my $s_t = localtime->strptime("2013-07-01 23:00:00","%Y-%m-%d %T");
my $e_t = localtime->strptime("2013-07-02 23:00:00","%Y-%m-%d %T");
$s_t->epoch;
$e_t->epoch;
[
  [
    $s_t,
    $e_t,
    1,1,1
  ]
]
--- expected_except: []


