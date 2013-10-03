package Time::Band;

use 5.15.9;
use Mouse;
use Data::Dumper;
use Time::Piece;
use Time::Piece::MySQL;
use autodie;
use Smart::Comments;

my $START_TIME = 0;#0:開始時間
my $END_TIME = 1;#1:終了時間
my $AE_FLG = 2;#2:肯定、否定フラグ
my $PRIORITY = 3;#3:優先度
my $ID = 4;#4:id

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

  my $band_times = $self->_get_all_times;
  my $rtn = $self->_to_no_relation($band_times);
  #余分な情報消す
  foreach (@$rtn) {
    delete $_->[2];
    delete $_->[3];
    delete $_->[4];
  }

  $rtn = $self->_sort_time($rtn); 
#  $self->_debug_print($rtn);
#  $rtn = $self->_add1sec($rtn); 
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

#--- expected: {1=>[2,3,4,5,6],7=>[8]}
  my $relation_group = $self->_relation_group($times);
### $relation_group;
  my $temp = {};
  
  foreach my $base_id (keys %$relation_group) {
    my $base_time = [$self->_by_time_id($base_id)];
    my $rel_ids = $relation_group->{$base_id};
    $base_time = $self->_divide($base_time,$rel_ids);
    #0は、exceptしまくった結果何もなかった場合0になってる。
    push $result ,@$base_time if (scalar @$base_time != 0);
  }

  return $result;
}


sub _divide {
  my $self = shift;
  my $base_time = shift;
  my $r = shift;

  my $result;
  my $id = shift @$r;
  #要素が一つなら返す。
  unless ($id) {
    my $ae_flg = $base_time->[0]->[$AE_FLG] || 2;
    if ($ae_flg == 1) {
      return $base_time;
    } elsif ($ae_flg == 2) {
      return [];
    } else {
      return [];
    }
  }

  my $tmp = [];
  foreach my $bt (@$base_time) {
#    say @$bt;
#    say "idは".$id;
    my $time = $self->_by_time_id($id);
    ### <line>
    say "base_time".$bt->[0]->datetime;
    say "base_time".$bt->[1]->datetime;
    say "base_time flg".$bt->[2];
    say "time".$time->[0]->datetime;
    say "time".$time->[1]->datetime;
    say "time flg".$time->[2];

    my $rtn = $self->_time_overlap_status($bt,$time);
    my $status = $rtn->[0];
    ### $status;
    my $times = $rtn->[1];

    my $add_except_flgA = $bt->[2];
    my $add_except_flgB = $time->[2];

    if ($status != 0) {

      my $flg_comment = {1=>"加",2=>"減"};
      say "flgAは".$flg_comment->{$add_except_flgA} .
      " / flgBは". $flg_comment->{$add_except_flgB};
      say "時間A:".$bt->[0]->datetime. " - " .$bt->[1]->datetime;
      say "時間B:".$time->[0]->datetime. " - " .$time->[1]->datetime;
      say " は時間が交わっています";
      ### $status

      my @time;
      if ($add_except_flgA == 1 && $add_except_flgB == 1) {
        if ($status == 0) {
#          print Dumper $times;
          @time = ([$times->[0],$times->[1],1],[$times->[2],$times->[3],1]);

          #時間が被った
          #|A |B B| A|
        } elsif ($status == 1) {
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
        } elsif ($status == 5 || $status == 6) {
          @time = [$times->[0],$times->[3],1];
        }
      } elsif ($add_except_flgA == 1 && $add_except_flgB == 2) {
        if ($status == 0) {
#          print Dumper $times;
          @time = ([$times->[0],$times->[1],1],[$times->[2],$times->[3],1]);

          #時間が被った
          #|A |B B| A|
        } elsif ($status == 1) {
          if ($times->[0] == $times->[1]) {
            @time = ([$times->[2],$times->[3],1]);
          } elsif ($times->[2] == $times->[3]) {
            @time = ([$times->[0],$times->[1],1]);
          } else {
            @time = ([$times->[0],$times->[1],1],[$times->[2],$times->[3],1]);
          }

          #時間が被った
          #|B |A A| B|
        } elsif ($status == 2) {
          #何もなし
#          @time = [$times->[1],$times->[2],1];
          #時間が被った
          #|A |B |A |B
        } elsif ($status == 3) {
          @time = [$times->[0],$times->[1],1];
          #時間が被った
          #|B |A |B |A
        } elsif ($status == 4) {
          @time = [$times->[2],$times->[3],1];
        } elsif ($status == 5) {
          #|A |A ==  B |B
          @time = [$times->[0],$times->[1],1];
        } elsif ($status == 6) {
          #|B |B ==  A |A
          @time = [$times->[2],$times->[3],1];
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
          if ($times->[0] == $times->[1]) {
            @time = ([$times->[2],$times->[3],1]);
          } elsif ($times->[2] == $times->[3]) {
            @time = ([$times->[0],$times->[1],1]);
          } else {
            @time = ([$times->[0],$times->[1],1],[$times->[2],$times->[3],1]);
          }
          #時間が被った
          #|A |B |A |B
        } elsif ($status == 3) {
#          $times->[2] += 1;
          @time = [$times->[2],$times->[3],1];
          #時間が被った
          #|B |A |B |A
        } elsif ($status == 4) {
#          $times->[1] -= 1;
          @time = [$times->[0],$times->[1],1];
        } elsif ($status == 5) {
          #|A |A ==  B |B
          @time = [$times->[2],$times->[3],1];
        } elsif ($status == 6) {
          #|B |B ==  A |A
          @time = [$times->[0],$times->[1],1];
        }
      }

      foreach my $t (@time) {
        if ($t) {
          print "結果は" .$t->[0] ." - ". $t->[1]."\n";
        }
      }
      say "====終了====";

      push @$tmp,@time;
    } else {
      push @$tmp, $bt;
      #ここで関連性がないものはいらない。
    }
  }

  $result = $tmp;
  if (scalar @$result == scalar @$base_time && scalar @$r == 0) {
#    "say scalar @$times . ":" .scalar @$result;"
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
  return $time[0];
}

sub _debug_print_by_id_info {
  my $self = shift;
  my $idss = shift;

  foreach my $ids (@$idss) {
    foreach my $id (@$ids) {
      my $time = $self->_by_time_id($id);
      my $st = $time->[$START_TIME];
      my $et = $time->[$END_TIME];
      printf("id:%d,st:%s,et:%s\n", $id,$st,$et);
    }
  }
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

  #|A |A |space|B |B
  #重なってないパターン
  if ($timeA->[0] <= $timeA->[1] && $timeA->[1] < $timeB->[0]
    && $timeB->[0] <= $timeB->[1] ) {

    $rtn = 0;
    $times = [$timeA->[0],$timeA->[1],$timeB->[0],$timeB->[1]];

    #|B |B |space|A |A
    #重なってないパターン
    # $timeB->[1] < $timeA->[0]; <= じゃないです。
  } elsif ($timeB->[0] <= $timeB->[1] && $timeB->[1] < $timeA->[0]
    && $timeA->[0] <= $timeA->[1] ) {

    $rtn = 0;
    $times = [$timeB->[0],$timeB->[1],$timeA->[0],$timeA->[1]];
  } elsif ($timeA->[0] <= $timeA->[1] && $timeA->[1] == $timeB->[0]
    && $timeB->[0] <= $timeB->[1] ) {
    #|A |A B|B

    $rtn = 5;
    $times = [$timeA->[0],$timeA->[1],$timeB->[0],$timeB->[1]];

  } elsif ($timeB->[0] <= $timeB->[1] && $timeB->[1] == $timeA->[0]
    && $timeA->[0] <= $timeA->[1] ) {
    #|B |B A|A
    $rtn = 6;
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
        #重なってる
        $relation->{$b1->[4]}->{$b2->[4]}++;
        $relation->{$b2->[4]}->{$b1->[4]}++;
      } else {
        #重なってない
        $no_relation->{$b1->[4]} = 1;
        $no_relation->{$b2->[4]} = 1;
      }
    }
  }

  ### $relation

  #relationから組み合わせをユニークにする
  my $temp_group = [];
  #キー数が多い奴を土台にする為
  #relation_idを関わる要素が多い方からソート
  my @keys_ary = sort {keys %{$relation->{$b}} <=> keys %{$relation->{$a}}} (keys %$relation);
  foreach my $key (@keys_ary) {
    if (exists $relation->{$key}) {
      my $rel_keys = $relation->{$key};
      my $keys_ary;
      foreach my $k (keys %$rel_keys) {
        delete $relation->{$k};
        push @$keys_ary,int $k;
      }
      $relation->{$key} = $keys_ary;
    }
  }
  ### @keys_ary;
  ### $relation;

  return $relation;
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

sub _add1sec {
  my $self = shift;
  my $time = shift;

#  $time = [map {$_->[1] ++ } @$time];
  $_->[1] += 1 for @$time;
#  say $_->[1] for @$time;
  return $time;
}

sub _debug_print {
  my $self = shift;
  my $times = shift;

  if (ref $times eq "ARRAY") {
    foreach my $ts (@$times) {
      foreach my $t (@$ts) {
        if (ref $t eq "Time::Piece") {
          my $dt = $t->datetime;
          ### $dt
        } else {
          ### $t
        }
      }
    }
  }
}

sub _get_all_times {
  my $self = shift;

  my $times = $self->_band_times;
  if (scalar @{$self->_base}  > 0) {
    #baseは優先度低
#    push @$times,$self->_base;
    unshift @$times,$self->_base;
  }
  return $times;
}

#relation_groupで出てきたidの配列をソートする奴
sub _sort_ids {
  my $self = shift;
  my $group = shift;

  foreach my $id (keys %$group) {
    $group->{$id} = [sort @{$group->{$id}}];
  }
  return $group;
}

sub _is_opposit_combi {
  my $self = shift;
  my $combi1 = shift;
  my $combi2 = shift;

  my $hash = {};
  map {$hash->{$_}++} @$combi1,@$combi2;
  my $count = grep {$hash->{$_} == 1} keys %$hash;
  if ($count == 0) {
    return 1;
  }
  return 0;
}

sub _debug_output_string_band_times {
  my $self = shift;

#  my $times = $self->_band_times;
  my $times = $self->_get_all_times;
  my $string;
  foreach my $ts (@$times) {
    $string .= $ts->[0]->datetime."-".$ts->[1]->datetime."-"."flg:".$ts->[2]."\n";
  }
  return $string;
}

1;
