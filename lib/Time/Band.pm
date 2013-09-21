package Time::Band;

use 5.15.9;
use Mouse;
use Data::Dumper;
use Time::Piece;
use Time::Piece::MySQL;
use autodie;
#use Smart::Comments;

#0:開始時間
#1:終了時間
#2:肯定、否定フラグ
#3:優先度
#4:id

has "start" => (is=>"rw",isa=>"Time::Piece");
has "end" => (is=>"rw",isa=>"Time::Piece");
has "band" => (is=>"rw",isa=>"ArrayRef",default=>sub {[]},lazy=>1);
has "_base" => (is=>"rw",isa=>"ArrayRef",default=>sub {[]},lazy=>1);
has "_band_times" => (is=>"rw",isa=>"ArrayRef",default=>sub {[]},lazy=>1);
has "_add_time" => (is=>"rw",isa=>"ArrayRef",default=>sub {[]});
has "_except_time" => (is=>"rw",isa=>"ArrayRef",default=>sub {[]});
has "_time_id" => (is=>"rw",default=>sub {1},lazy=>1);
has "_priority" => (is=>"rw",default=>sub {1},lazy=>1);

__PACKAGE__->meta->make_immutable();

sub BUILD {
  my $self = shift;

  if ($self->start && $self->end) {
    $self->_base([$self->start,$self->end,1,$self->_priority++,$self->_time_id++]);
  }
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

  &_is_same_time($start,$end); 
  
  if ($priority) {
    my $ary = $self->_band_times;
    my @after = splice @$ary , $priority - 1;
    push @{$self->_band_times} , [$start,$end,1]; #1:add
    push @{$self->_band_times} , @after;
  } else {
    push @{$self->_band_times} , [$start,$end,1,$self->_priority++,$self->_time_id++];
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
    push @{$self->_band_times} , [$start,$end,2,$self->_priority++,$self->_time_id++];
  }
}

sub result {
  my $self = shift;

  #先頭にある奴が優先度高
  my $band_times = $self->_band_times;
  
  #baseは一番弱い
  if (scalar @{$self->_base}  > 0) {
    push @$band_times,$self->_base;
  }

  my $rtn = $self->_to_no_relation($band_times);
  #余分な情報消す
  foreach (@$rtn) {
    delete $_->[2];
    delete $_->[3];
    delete $_->[4];
  }

  $rtn = $self->_sort_time($rtn); 
  return $rtn;
}

sub _to_no_relation {
  my $self = shift;
  my $times = shift;

  my @band_timesA = @$times;
  my $result = [];

  #一つしかなかったら、早めに返してあげる。
  if (scalar @$times == 1) {
    if ($times->[0]->[2] == 2) {
      return [];
    } else {
      return $times;
    }
  }

  my ($relation_group,$no_relation) = $self->_relation_group($times);
#  say Dumper $relation_group;
  my $temp = {};
  
  foreach my $r (@$relation_group) {

    #ここはひとまとめ
    my $base_id = shift @$r;
    my $base_time = [$self->_by_time_id($base_id)];

    $base_time = $self->_divide($base_time,$r);
    push $result ,@$base_time;
  }

  return $result;
}

sub _divide {
  my $self = shift;
  my $base_time = shift;
  my $r = shift;

  my $result;
  my $id = shift @$r;
#  say @$base_time;
  unless ($id) {
#    say scalar @$base_time;
    return $base_time;
  }

  my $tmp = [];
  foreach my $bt (@$base_time) {
#    say @$bt;
#    say "idは".$id;
    my $time = $self->_by_time_id($id);
    my $rtn = $self->_time_overlap_status($bt,$time);
    my $status = $rtn->[0];
#    say $status;
    my $times = $rtn->[1];

    my $add_except_flgA = $bt->[2];
    my $add_except_flgB = $time->[2];

    if ($status != 0) {

=pod
      my $flg_comment = {1=>"加",2=>"減"};
      say "flgAは".$flg_comment->{$add_except_flgA} .
      " / flgBは". $flg_comment->{$add_except_flgB};
      say $bt->[0]->datetime. " - " .$bt->[1]->datetime;
      say $time->[0]->datetime. " - " .$time->[1]->datetime;
      say " は時間が交わっています";
=cut

      my @time;
      if ($add_except_flgA == 1 && $add_except_flgB == 1) {
        if ($status == 0) {
#          print Dumper $times;
          @time = ([$times->[0],$times->[1],1],[$times->[2],$times->[3],1]);

          #時間が被った
          #|A |B B| A|
        } elsif ($status == 1) {
          say "satus 1";
          @time = [$times->[0],$times->[3],1];

          #時間が被った
          #|B |A A| B|
        } elsif ($status == 2) {
          @time = [$times->[0],$times->[3],1];
          #時間が被った
          #|A |B |A |B
        } elsif ($status == 3) {
#          say "status 3";
          @time = [$times->[0],$times->[3],1];
          #時間が被った
          #|B |A |B |A
        } elsif ($status == 4) {
          @time = [$times->[0],$times->[3],1];
        }
      } elsif ($add_except_flgA == 1 && $add_except_flgB == 2) {
        if ($status == 0) {
#          print Dumper $times;
          @time = ([$times->[0],$times->[1],1],[$times->[2],$times->[3],1]);

          #時間が被った
          #|A |B B| A|
        } elsif ($status == 1) {
          say "status 1 1 & 2";
          #ここおけ
          $times->[1] -= 1;
          $times->[2] += 1;
          @time = ([$times->[0],$times->[1],1],[$times->[2],$times->[3],1]);

          #時間が被った
          #|B |A A| B|
        } elsif ($status == 2) {
          say "status 2";
          @time = [$times->[1],$times->[2],1];
          #時間が被った
          #|A |B |A |B
        } elsif ($status == 3) {
#          say "status 3 1 & 2";
          $times->[1] -= 1;
          @time = [$times->[0],$times->[1],1];
          #時間が被った
          #|B |A |B |A
        } elsif ($status == 4) {
#          say "status 4 koko";
          @time = [$times->[1],$times->[3],1];
#          say $times->[1],$times->[3];
        }
      } elsif ($add_except_flgA == 2 && $add_except_flgB == 1) {
        if ($status == 0) {
          #被りなし
          @time = ([$times->[0],$times->[1],1],[$times->[2],$times->[3],1]);

          #時間が被った
          #|A |B B| A|
        } elsif ($status == 1) {
          @time = [];

          #時間が被った
          #|B |A A| B|
        } elsif ($status == 2) {
          $times->[1] -= 1;
          $times->[2] += 1;
          @time = ([$times->[0],$times->[1],1],[$times->[2],$times->[3],1]);
          #時間が被った
          #|A |B |A |B
        } elsif ($status == 3) {
          $times->[2] += 1;
          @time = [$times->[2],$times->[3],1];
          #時間が被った
          #|B |A |B |A
        } elsif ($status == 4) {
          $times->[1] -= 1;
          @time = [$times->[0],$times->[1],1];
        }
      }

#      say $time->[0];
#      say "結果は" .$time[0]->[0] ." - ". $time[0]->[1];
      if ($time[1]) {
#        say "結果は" .$time[1]->[0] ." - ". $time[1]->[1];
      }
#      say @time;
      push @$tmp,@time;
    } else {
      push @$tmp, $bt;
      #ここで関連性がないものはいらない。
    }
  }
#  say 99999;
#  say $tmp;

  $result = $tmp;
  if (scalar @$result == scalar @$base_time && scalar @$r == 0) {
###    "say scalar @$times . ":" .scalar @$result;"
    return $result;
  } else {
#    say "recursive".scalar @$result . ":" .scalar @$base_time;
#    say $result->[0];
    return $self->_divide($result,$r);
  }
}

sub _by_time_id {
  my $self = shift;
  my $id = shift;

  my @band_times = @{$self->_band_times};
  my @time = grep {$_->[4] == $id} @band_times;
#  say $time->[0]->[0];
  return $time[0];
}

my $s_t1 = localtime->from_mysql_datetime("2013-07-01 10:00:00");
my $e_t1 = localtime->from_mysql_datetime("2013-07-01 23:00:00");
my $s_t2 = localtime->from_mysql_datetime("2013-07-01 19:00:00");
my $e_t2 = localtime->from_mysql_datetime("2013-07-01 20:59:59");
my $s_t3 = localtime->from_mysql_datetime("2013-07-01 13:00:00");
my $e_t3 = localtime->from_mysql_datetime("2013-07-01 14:59:59");
=pod
my $tb = Time::Band->new(start=>$s_t1,end=>$e_t1);
$tb->add($s_t2,$e_t2);
$tb->except($s_t3,$e_t3);
my $res = $tb->result;
print "結果の要素数は、".scalar @$res."です\n";
#print Dumper $res->[0]->[0] ,$res->[0]->[1];
print "結果は、\n";
foreach my $r (@$res) {
  say $r->[0] ." > " .$r->[1];
}
=cut

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
  #重なってないパターン
  # $timeA->[1] < $timeB->[0]; <= じゃないです。
  if ($timeA->[0] <= $timeA->[1] && $timeA->[1] < $timeB->[0]
    && $timeB->[0] <= $timeB->[1] ) {

    $rtn = 0;
    $times = [$timeA->[0],$timeA->[1],$timeB->[0],$timeB->[1]];

    #|B |B |A |A
    #重なってないパターン
    # $timeB->[1] < $timeA->[0]; <= じゃないです。
  } elsif ($timeB->[0] <= $timeB->[1] && $timeB->[1] < $timeA->[0]
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

#重なっている時間帯をまとめる
#重なってないやつもつっこんどく
#
=pod
データ形式
[
  [
    1,2 #id 1,2が関係性がある
  ],
  [
    3,4 #id 3,4が関係性がある
  ],
  [
    5 #単一のやつ
  ]
]
=cut
sub _relation_group {
  my $self = shift;
  my $times = shift;

  my @band_timesA = @$times;
  my @band_timesB = @$times;
  my $relation = {};
  my $no_relation = {};

  #関係性のあるモノはrelationに
  #ないものno_relationに
  foreach my $b1 (@band_timesA) {
    shift @band_timesB; #同じのと比較しないように
    foreach my $b2 (@band_timesB) {
#      say $b1->[0]->datetime." - ".$b1->[1]->datetime . " と "
#      . $b2->[0]->datetime." - ".$b2->[1]->datetime."を比較します";

      #重なっているステータスを確認
      my $rtn = $self->_time_overlap_status($b1,$b2);
      my $status = $rtn->[0];
      my $times = $rtn->[1];
      if ($status != 0) {
        push @{$relation->{$b1->[4]}} ,$b2->[4];
        push @{$relation->{$b2->[4]}} ,$b1->[4];
      } else {
        $no_relation->{$b1->[4]} = $b1->[4];
        $no_relation->{$b2->[4]} = $b2->[4];
      }
    }
  }

  #say Dumper $no_relation;
#  say Dumper keys %$no_relation;

  #relationから組み合わせをユニークにする
  my $temp_group = [];
  foreach my $key (keys %$relation) {
    if (exists $relation->{$key}) {
      foreach my $rel (@{$relation->{$key}}) {
        #関連している時間たち
        my $rel_key = $relation->{$rel};
        if (scalar @$rel_key == 1) {
          if ($key == $rel_key->[0]) {
            #関連しているのが 使用されている組み、
            #要素が入れ替わっているだけの組み は消す
            delete $relation->{$rel};
          } else {
            warn "error";
          }
        } else {
          #別のやつで繋がってるやつあり
          #ここ処理追加しないと駄目だと思う
        }
      }
#      push @$temp_group,[$key,$rel];
    }
  }

  
  foreach my $key (keys %$relation) {
    my $ary = [int $key,@{$relation->{$key}}];
    push @$temp_group,$ary;
  }
  foreach my $key (keys %$no_relation) {
    my $ids = [$key];
    push @$temp_group,$ids;
  }
  return $temp_group;
}

sub _is_same_time {
  my $timesA = shift;
  my $timesB = shift;

  if ($timesA == $timesB) {
    warn "same time !! misstake?";
    return 1;
  } else {
    return 0;
  }
}

sub _sort_time {
  my $self = shift;
  my $time = shift;

  return $time if (scalar @$time == 1);

  $time = [sort {$a->[0] <=> $b->[0]} @$time];
  return $time;
}


1;
