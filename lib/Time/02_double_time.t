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

filters {
  expected=>["eval"],
};

foreach my $block (blocks()) {
  my $s_t1 = localtime->from_mysql_datetime($block->start_time);
  my $e_t1 = localtime->from_mysql_datetime($block->end_time);

  my $expected = $block->expected;
  my $tb = Time::Band->new(start=>$s_t1,end=>$e_t1);
  my $res = $tb->result;
  foreach my $e (@$expected) {
    foreach my $r (@$res) {
      is($e->[0],$r->[0],sprintf("%s %s new",$block->name,$r->[0]->datetime));
      is($e->[1],$r->[1],sprintf("%s %s new",$block->name,$r->[1]->datetime));
    }
  }
}


done_testing;

__DATA__

=== single time
--- start_time: 2013-07-01 10:00:00
--- end_time: 2013-07-01 23:00:00
--- expected
[
  [
    'Mon Jul  1 10:00:00 2013',
    'Mon Jul  1 23:00:00 2013'
  ]
]

=== over_time
--- start_time: 2013-07-01 23:00:00
--- end_time: 2013-07-02 23:00:00
--- expected
[
  [
    'Mon Jul  1 23:00:00 2013',
    'Tue Jul  2 23:00:00 2013'
  ]
]


