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

plan tests=>6;

filters {
  expected=>["eval"],
};

my ($s_t1,$e_t1,$s_t2,$e_t2,$s_t3,$e_t3);
foreach my $block (blocks()) {

  my $expected = $block->expected;

  $s_t1 = localtime->from_mysql_datetime($block->start_time1);
  $e_t1 = localtime->from_mysql_datetime($block->end_time1);

  my $tb = Time::Band->new(start=>$s_t1,end=>$e_t1);

  if ($block->start_time2) {
    $s_t2 = localtime->from_mysql_datetime($block->start_time2);
    $e_t2 = localtime->from_mysql_datetime($block->end_time2);
    $tb->add($s_t2,$e_t2);
  }

  if ($block->start_time3) {
    $s_t3 = localtime->from_mysql_datetime($block->start_time3);
    $e_t3 = localtime->from_mysql_datetime($block->end_time3);
    $tb->add($s_t3,$e_t3);
  }

  my $times = $tb->_get_all_times;
  my $group = $tb->_relation_group($times);
  $group = $tb->_sort_ids($group);
#  $tb->_debug_print_by_id_info($group);

  is_deeply($group,$expected,$block->name);
}

done_testing;

__DATA__

=== double time A A B B
--- start_time1: 2013-07-01 10:00:00
--- end_time1: 2013-07-01 15:00:00
--- start_time2: 2013-07-01 15:00:00
--- end_time2: 2013-07-01 16:00:00
--- start_time3:
--- end_time3:
--- expected: [ [1,[2]] ]

=== double time B B A A
--- start_time1: 2013-07-01 10:00:00
--- end_time1: 2013-07-01 15:00:00
--- start_time2: 2013-07-01 15:00:00
--- end_time2: 2013-07-01 16:00:00
--- start_time3:
--- end_time3:
--- expected: [ [1,[2]] ]

=== triple time A A space B B space C C
--- start_time1: 2013-07-01 10:00:00
--- end_time1: 2013-07-01 13:00:00
--- start_time2: 2013-07-01 14:00:00
--- end_time2: 2013-07-01 16:00:00
--- start_time3: 2013-07-01 17:00:00
--- end_time3: 2013-07-01 23:00:00
--- expected: [ [1,[],] [ 3,[] ], [ 2, [] ] ]

=== triple time A A B B space C C
--- start_time1: 2013-07-01 10:00:00
--- end_time1: 2013-07-01 14:00:00
--- start_time2: 2013-07-01 14:00:00
--- end_time2: 2013-07-01 16:00:00
--- start_time3: 2013-07-01 17:00:00
--- end_time3: 2013-07-01 23:00:00
--- expected: [ [ 1,[2] ], [ 3,[] ], ]

=== triple time A B A B C C
--- start_time1: 2013-07-01 10:00:00
--- end_time1: 2013-07-01 15:00:00
--- start_time2: 2013-07-01 14:00:00
--- end_time2: 2013-07-01 16:00:00
--- start_time3: 2013-07-01 16:00:00
--- end_time3: 2013-07-01 23:00:00
--- expected: [ [ 1,[2]],[2,[3]] ]

=== triple time A B B A C C
--- start_time1: 2013-07-01 10:00:00
--- end_time1: 2013-07-01 16:00:00
--- start_time2: 2013-07-01 14:00:00
--- end_time2: 2013-07-01 16:00:00
--- start_time3: 2013-07-01 16:00:00
--- end_time3: 2013-07-01 23:00:00
--- expected: [ [1,[2,3]] ]

=== triple time A B B C C A
--- start_time1: 2013-07-01 10:00:00
--- end_time1: 2013-07-01 23:30:00
--- start_time2: 2013-07-01 14:00:00
--- end_time2: 2013-07-01 16:00:00
--- start_time3: 2013-07-01 16:00:00
--- end_time3: 2013-07-01 23:00:00
--- expected: [ [1,[2,3]] ]
