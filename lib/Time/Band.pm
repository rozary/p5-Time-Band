package Time::Band;

BEGIN {
  use Test::MockTime qw/set_absolute_time/;
  set_absolute_time('2012-01-08T00:00:00Z');
}

use Mouse;
use Data::Dumper;
use CGI::Carp;
use Time::Piece;

has "start" => (is=>"rw",isa=>"Time::Piece");
has "end" => (is=>"rw",isa=>"Time::Piece");
has "band" => (is=>"rw",isa=>"ArrayRef");
has "except" => (is=>"rw",isa=>"ArrayRef");

sub BUILD {
  my $self = shift;
  
  $self->{band} = [[$self->start,$self->end]];
}

sub add_except {
  my $self = shift;
  my $start = shift;
  my $end = shift;

  push @{$self->{except}}, [$start,$end];
}

sub result {
  my $self = shift;

  my $buf = [];

  my $e_count = 0;
  while (my $except = shift @{$self->{except}}) {
    push @$buf,["e",$e_count,$except->[0]];
    push @$buf,["e",$e_count,$except->[1]];
    $e_count++;
  }

  my $b_count = 0;
  while (my $band = shift @{$self->band}) {
    push @$buf,["b",$b_count,$band->[0]];
    push @$buf,["b",$b_count,$band->[1]];
    $b_count++;
  }

  my $flg = {e=>{},b=>{}};
  my $band_data = [];
  foreach my $data (sort {$a->[2] <=> $b->[2] || $a->[0] cmp $b->[0]} @$buf) {
    if (0) {
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
          push @$band_data,$data->[2];
        }
        if ($b_num > 0 && $e_num == 0) {
          #ok期間内で、ngフラグが終わったら入れる。
          push @$band_data,$data->[2];
        }
      }
    }
  }
#  print "\n=====\n";

  return $band_data;
#  return $self->band;
}


package main;

use 5.12.3;
use Time::Piece;
use Data::Dumper;

my $t1 = localtime();
my $t2 = localtime() + 1200;

my $band = Time::Band->new(start=>$t1,end=>$t2);

my $t3 = localtime() + 9;
my $t4 = localtime() + 180;

$band->add_except($t3,$t4);

my $t5 = localtime() + 60;
my $t6 = localtime() + 1200;
$band->add_except($t5,$t6);

foreach my $r (@{$band->result}) {
  say $r->datetime;
}


1;
