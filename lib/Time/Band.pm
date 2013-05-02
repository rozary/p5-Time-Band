package Time::Band;

use Mouse;
use Time::Piece;

has "start" => (is=>"rw",isa=>"Time::Piece");
has "end" => (is=>"rw",isa=>"Time::Piece");
has "band" => (is=>"rw",isa=>"ArrayRef",default=>sub {[]});
has "_except_time" => (is=>"rw",isa=>"ArrayRef",default=>sub {[]});

__PACKAGE__->meta->make_immutable();

sub BUILD {
  my $self = shift;
  
  $self->{band} = [[$self->start,$self->end]];
}

sub except {
  my $self = shift;
  my $start = shift;
  my $end = shift;

  unless ( ref $start eq "Time::Piece") {
    die "first args is not Time::Piece object at except";
  }
  unless ( ref $end eq "Time::Piece") {
    die "second args is not Time::Piece object at except";
  }

  push @{$self->_except_time}, [$start,$end];
}

sub result {
  my $self = shift;

  my $buf = [];

  my $e_count = 0;
  foreach my $except (@{$self->_except_time}) {
    push @$buf,["e",$e_count,$except->[0]];
    push @$buf,["e",$e_count,$except->[1]];
    $e_count++;
  }

  my $b_count = 0;
  foreach my $band (@{$self->band}) {
    push @$buf,["b",$b_count,$band->[0]];
    push @$buf,["b",$b_count,$band->[1]];
    $b_count++;
  }

  my $flg = {e=>{},b=>{}};
  my $band_data = [];
  foreach my $data (sort {$a->[2] <=> $b->[2] || $a->[0] cmp $b->[0]} @$buf) {
    if (0) {
      use Data::Dumper;
#      print Dumper $data;
      print $data->[2]->datetime;
      print Dumper $flg;
      print "\n";
      sleep 1;
    }

    if (exists $flg->{$data->[0]}->{$data->[1]}) {

      delete $flg->{$data->[0]}->{$data->[1]};
      my $b_num = scalar keys %{$flg->{b}};
      my $e_num = scalar keys %{$flg->{e}};

      if ( $data->[0] eq "b" ) {
        if ($b_num == 0 && $e_num == 0) {
          push @$band_data,$data->[2];
        }
      }

      if ( $data->[0] eq "e") {
        if ( $b_num > 0 && $e_num == 0) {
          push @$band_data,$data->[2];
        }
      }

    } else {
#      print $data->[2]->datetime;
      my $last = $#$band_data;
      $flg->{$data->[0]}->{$data->[1]}++;
      my $b_num = scalar keys %{$flg->{b}};
      my $e_num = scalar keys %{$flg->{e}};

      #ng期間でない時のokは入れる。
      if ( $data->[0] eq "b" && $e_num == 0) {
        push @$band_data,$data->[2];
      }

      if ( $data->[0] eq "e" ) {
        if ($b_num > 0 && $e_num == 1) {
          #ok期間内で、ngフラグが立ったら入れる。
          if ( $band_data->[$last] == $data->[2] ) {
            pop @$band_data;
          } else {
            push @$band_data,$data->[2];
          }
        }
        if ($b_num > 0 && $e_num == 0) {
          #ok期間内で、ngフラグが終わったら入れる。
          push @$band_data,$data->[2];
        }
      }
    }
  }
#  print "\n=====\n";
  my $count = 0;
  my $result;
  while (my $rt = shift @$band_data) {
    my $last = $#$result;
    if ($count % 2 == 0) {
      #start_time
      push @$result,[$rt];
    } else {
      if ($result->[$last]->[0] == $rt) {
        #when start time equal end time
        pop @$result;
      } else {
        push @{$result->[$last]},$rt;
      }
    }
    $count++;
  }

  return $result;
}

1;
