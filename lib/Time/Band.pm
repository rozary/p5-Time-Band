package Time::Band;

use 5.15.9;
use Mouse;
use Data::Dumper;
use Time::Piece;
use Time::Piece::MySQL;

$|=1;

has "start" => (is=>"rw",isa=>"Time::Piece",required=>1);
has "end" => (is=>"rw",isa=>"Time::Piece",required=>1);
has "band" => (is=>"rw",isa=>"ArrayRef",default=>sub {[]},lazy=>1);
has "_base" => (is=>"rw",isa=>"ArrayRef",default=>sub {[]},lazy=>1);
has "_band_times" => (is=>"rw",isa=>"ArrayRef",default=>sub {[]},lazy=>1);
has "_add_time" => (is=>"rw",isa=>"ArrayRef",default=>sub {[]});
has "_except_time" => (is=>"rw",isa=>"ArrayRef",default=>sub {[]});

__PACKAGE__->meta->make_immutable();

sub BUILD {
  my $self = shift;

  #基本 一つ
  $self->_base([$self->start,$self->end,1]);
}

sub add {
  my $self = shift;
  my $start = shift;
  my $end = shift;
  my $priority = shift;

  unless ( $self->_is_time_piece($start)) {
    die "first args is not Time::Piece object at except";
  }
  unless ( $self->_is_time_piece($end)) {
    die "second args is not Time::Piece object at except";
  }
  
  if ($priority) {
    my $ary = $self->_band_times;
    my @after = splice @$ary , $priority - 1;
    push @{$self->_band_times} , [$start,$end,1]; #1:add
    push @{$self->_band_times} , @after;
  } else {
    push @{$self->_band_times} , [$start,$end,1];
  }
}

sub except {
  my $self = shift;
  my $start = shift;
  my $end = shift;
  my $priority = shift;

  unless ( $self->_is_time_piece($start)) {
    die "first args is not Time::Piece object at except";
  }
  unless ( $self->_is_time_piece($end)) {
    die "second args is not Time::Piece object at except";
  }


  if ($priority) {
    my $ary = $self->_band_times;
    my @after = splice @$ary , $priority - 1;
    push @{$self->_band_times} , [$start,$end,2]; #2:except
    push @{$self->_band_times} , @after;
  } else {
    push @{$self->_band_times} , [$start,$end,2];
  }
}

sub result {
  my $self = shift;

#  my $band_times = [reverse @{$self->_band_times}];
  #先頭にある奴が優先度高
  my $band_times = $self->_band_times;
  
  #基本一つ
  my $base = $self->_base || [];

  #baseは一番弱い
  push @$band_times,$base;

  return $self->_to_no_relation($band_times);

}

sub _to_no_relation {
  my $self = shift;
  my $times = shift;

  my @band_timesA = @$times;
  my @band_timesB = @$times;
  my $result = [];

  #一つしかなかったら、早めに返してあげる。
  if (scalar @$times == 1) {
    return $times;
  }

  my $relation = [];
  my $relation_temp = {};
  my $no_relation = {};
  my $checked_temp = {};

  #関係性のある時間を結合していって、関係性がなくなったら終了
  foreach my $b1 (@band_timesA) {
    foreach my $b2 (@band_timesB) {
      my $checked_key = $b1->[0]->epoch
      .$b1->[1]->epoch
      .$b2->[0]->epoch
      .$b2->[1]->epoch;
      if (exists $checked_temp->{$checked_key}) {
        next;
      }

      $checked_key = $b2->[0]->epoch
      .$b2->[1]->epoch
      .$b1->[0]->epoch
      .$b1->[1]->epoch;
      $checked_temp->{$checked_key}++;

#          say $b1->[0] . " target  " . $b2->[0];
      if ($b1->[0] != $b2->[0] || $b1->[1] != $b2->[1]) {
        my $rtn = $self->_time_overlap_status($b1,$b2);
        my $status = $rtn->[0];
        my $times = $rtn->[1];
        if ($status != 0) {
          say $b1->[0] . " >>>>> " . $b2->[0];
#          if (my $b2_epoch = $relation_temp->{$b2->[0]->epoch}) {
          #反対の組み合わせを弾く
#            if ($b1->[0] == $b2_epoch->[1] && $b1->[1] == $b2_epoch->[0]) {
#            } else {
#            }
#          } else {
#            $relation_temp->{$b1->[0]->epoch} = [$b1,$b2];
#            push @$relation , [$b1,$b2];
#          }
          push @$relation , [$b1,$b2];
        } else {
          #関係性がないやつ
          $no_relation->{$b1->[0]->epoch} = $b1;
#          say $b1->[0] . " >>>>> " . $b2->[0];
        }
      }
    }
  }


  my $temp = {};
  foreach my $rel (@$relation) {
    #関係性がどこかである奴は削除
    if (my $no_rel = $no_relation->{$rel->[0]->[0]->epoch}) {
      if ($no_rel->[0] == $rel->[0]->[0] && $no_rel->[1] == $rel->[0]->[1]) {
        delete $no_relation->{$rel->[0]->[0]->epoch};
      }
    }

    my $rtn = $self->_time_overlap_status(@$rel);
    my $status = $rtn->[0];
    my $times = $rtn->[1];
    my @time;

    #Aが優先度高
    my $add_except_flgA = $rel->[0]->[2];
    my $add_except_flgB = $rel->[1]->[2];
    say $add_except_flgA . " flg ". $add_except_flgB;
    say $rel->[1]->[0]. " :::" .$rel->[1]->[1];
    say $rel->[0]->[0]. " :::" .$rel->[0]->[1];
    
        say $times->[0],$times->[1],$times->[2],$times->[3];

    if ($add_except_flgA == 1 && $add_except_flgB == 1) {
      if ($status == 0) {
#          print Dumper $times;
        @time = ([$times->[0],$times->[1]],[$times->[2],$times->[3]]);

        #時間が被った
        #|A |B B| A|
      } elsif ($status == 1) {
        say "satus 1";
        @time = [$times->[0],$times->[3]];

        #時間が被った
        #|B |A A| B|
      } elsif ($status == 2) {
        @time = [$times->[0],$times->[3]];
        #時間が被った
        #|A |B |A |B
      } elsif ($status == 3) {
        say "satus 3";
        @time = [$times->[0],$times->[3]];
        #時間が被った
        #|B |A |B |A
      } elsif ($status == 4) {
        @time = [$times->[0],$times->[3]];
      }
    } elsif ($add_except_flgA == 1 && $add_except_flgB == 2) {
      if ($status == 0) {
#          print Dumper $times;
        @time = ([$times->[0],$times->[1]],[$times->[2],$times->[3]]);

        #時間が被った
        #|A |B B| A|
      } elsif ($status == 1) {
        say "status 1";
        @time = [$times->[0],$times->[3]];

        #時間が被った
        #|B |A A| B|
      } elsif ($status == 2) {
        say "status 2";
        @time = [$times->[1],$times->[2]];
        #時間が被った
        #|A |B |A |B
      } elsif ($status == 3) {
        say "status 3";
        @time = [$times->[0],$times->[2]];
        #時間が被った
        #|B |A |B |A
      } elsif ($status == 4) {
        say "status 4 koko";
        @time = [$times->[1],$times->[3]];
        say $times->[1],$times->[3];
      }
    } elsif ($add_except_flgA == 2 && $add_except_flgB == 1) {
      if ($status == 0) {
        #被りなし
        @time = ([$times->[0],$times->[1]],[$times->[2],$times->[3]]);

        #時間が被った
        #|A |B B| A|
      } elsif ($status == 1) {
        @time = [];

        #時間が被った
        #|B |A A| B|
      } elsif ($status == 2) {
        $times->[1] -= 1;
        $times->[2] += 1;
        @time = ([$times->[0],$times->[1]],[$times->[2],$times->[3]]);
        #時間が被った
        #|A |B |A |B
      } elsif ($status == 3) {
        $times->[2] += 1;
        @time = [$times->[2],$times->[3]];
        #時間が被った
        #|B |A |B |A
      } elsif ($status == 4) {
        $times->[1] -= 1;
        @time = [$times->[0],$times->[1]];
      }
    }

    if (my $flg = $temp->{$time[0]->[0]->epoch.$time[0]->[1]->epoch}) {
      #同じのはいらない。
    } else {
      $temp->{$time[0]->[0]->epoch.$time[0]->[1]->epoch} ++;
      push @$result,$time[0];
    }

    if ($time[1]) {
      if (my $flg = $temp->{$time[1]->[0]->epoch.$time[1]->[1]->epoch}) {
        #同じのはいらない。
      } else {
        $temp->{$time[1]->[0]->epoch.$time[1]->[1]->epoch} ++;
        push @$result,$time[1];
      }
    }
  }

  foreach my $no_rel (keys %$no_relation) {
    push @$result,$no_relation->{$no_rel};
  }

  foreach my $res (@$result) {
#    say $res->[0] ." end ". $res->[1];
  }

  #全部疎になった?
  if (scalar @$times == scalar @$result) {
    say scalar @$times . ":" .scalar @$result;
    return $result;
  } else {
    say "recursive".scalar @$times . ":" .scalar @$result;
    $self->_to_no_relation($result);
  }
}

my $s_t1 = localtime->from_mysql_datetime("2013-07-01 10:00:00");
my $e_t1 = localtime->from_mysql_datetime("2013-07-01 23:00:00");

my $s_t2 = localtime->from_mysql_datetime("2013-07-01 12:00:00");
my $e_t2 = localtime->from_mysql_datetime("2013-07-01 21:59:59");

my $tb = __PACKAGE__->new(start=>$s_t1,end=>$e_t1);
$tb->except($s_t2,$e_t2);
my $res = $tb->result;
print "result count is ".scalar @$res."\n";
#print Dumper $res->[0]->[0] ,$res->[0]->[1];
foreach my $r (@$res) {
  say $r->[0] ." > " .$r->[1];
}

print "




";
#print Dumper $tb->_add_times;

#print $tb->_is_time_overlap([$s_t1,$e_t1],[$s_t2,$e_t2]);

sub _is_time_overlap {
  my $self = shift;
  my $time1 = shift || die "need time1";
  my $time2 = shift || die "need time2";

  my $flg = 1;
  if ($time1->[0] >= $time2->[0] && $time1->[0] >= $time2->[1]) {
    # 2 <= 1
    $flg = 0;
  } elsif ($time1->[1] <= $time2->[0] && $time1->[1] <= $time2->[1]) {
    # 1 <= 2
    $flg = 0;
  }
  return $flg;
}

sub _time_overlap_status {
  my $self = shift;
  my $timeA = shift || die "need timeA";
  my $timeB = shift || die "need timeB";


  my $rtn = 0;
  my $times = [];
  #ソートしてAABBの順番を判定する処理って早いかな?

  #|A |A |B |B
  if ($timeA->[0] <= $timeA->[1] && $timeA->[1] <= $timeB->[0]
    && $timeB->[0] <= $timeB->[1] ) {

    $rtn = 0;
    $times = [$timeA->[0],$timeA->[1],$timeB->[0],$timeB->[1]];

    #|B |B |A |A
  } elsif ($timeB->[0] <= $timeB->[1] && $timeB->[1] <= $timeA->[0]
    && $timeA->[0] <= $timeA->[1] ) {

    $rtn = 0;
    $times = [$timeB->[0],$timeB->[1],$timeA->[0],$timeA->[1]];

    #|A |B B| A|
  } elsif ($timeA->[0] <= $timeB->[0] && $timeB->[0] <= $timeB->[1]
    && $timeB->[1] <= $timeA->[1] ) {

    $rtn = 1;
    $times = [$timeA->[0],$timeB->[0],$timeB->[1],$timeA->[1]];

    #|B |A A| B|
  } elsif ($timeB->[0] <= $timeA->[0] && $timeA->[0] <= $timeA->[1]
    && $timeA->[1] <= $timeB->[1]) {

    $rtn = 2;
    $times = [$timeB->[0],$timeA->[0],$timeA->[1],$timeB->[1]];

    #|A |B |A |B
  } elsif ($timeA->[0] <= $timeB->[0] && $timeB->[0] <= $timeA->[1]
    && $timeA->[1] <= $timeB->[1]) {

    $rtn = 3;
    $times = [$timeA->[0],$timeB->[0],$timeA->[1],$timeB->[1]];

    #|B |A |B |A
  } elsif ($timeB->[0] <= $timeA->[0] && $timeA->[0] <= $timeB->[1]
    && $timeB->[1] <= $timeA->[1]) {

    $rtn = 4;
    $times = [$timeB->[0],$timeA->[0],$timeB->[1],$timeA->[1]];
  }

  return [$rtn,$times];
}


sub _add_times {
  my $self = shift;

  my $add =  grep {$_->[2] == 1} @{$self->_band_times};
  return $add;
}

sub _except_times {
  my $self = shift;

  my $add =  grep {$_->[2] == 2} @{$self->_band_times};
  return $add;
}

sub _is_time_piece {
  my $self = shift;
  return (ref $_[0] eq "Time::Piece") ? 1 : 0;
}

1;
