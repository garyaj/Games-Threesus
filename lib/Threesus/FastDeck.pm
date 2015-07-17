# Stores count totals of the current deck for the purpose of counting cards. 
package Threesus::FastDeck;
use v5.14;
use Object::Tiny qw{
  Ones
  Twos
  Threes
};

use enum qw{Zero One Two Three Bonus};

# Initializes the card counts to their full-deck values.
sub Initialize {
  my $self = shift;
  $self->{Ones} = 4;
  $self->{Twos} = 4;
  $self->{Threes} = 4;
}

sub InitFromDeck {
  my ($self, $deck) = @_;
  my $cardCounts = $deck->GetCountsOfCards;
  $self->{Ones} = $cardCounts->{1} // 0;
  $self->{Twos} = $cardCounts->{2} // 0;
  $self->{Threes} = $cardCounts->{3} // 0;
}

# Removes a single 1 card from the deck.
sub RemoveOne {
  my $self = shift;
  $self->Ones($self->Ones-1);
  if($self->Ones + $self->Twos + $self->Threes == 0) {
    $self->Initialize;
  }
}

# Removes a single 2 card from the deck.
sub RemoveTwo {
  my $self = shift;
  $self->Twos($self->Twos-1);
  if($self->Ones + $self->Twos + $self->Threes == 0) {
    $self->Initialize;
  }
}

# Removes a single 3 card from the deck.
sub RemoveThree {
  my $self = shift;
  $self->Threes($self->Threes-1);
  if($self->Ones + $self->Twos + $self->Threes == 0) {
    $self->Initialize;
  }
}

# Removes a single card of the specified value from the deck.
sub Remove {
  my ($self, $cardIndex) = @_;
    if    ($cardIndex == 1) { $self->{Ones} = $self->Ones - 1 }
    elsif ($cardIndex == 2) { $self->{Twos} = $self->Twos - 1 }
    elsif ($cardIndex == 3) { $self->{Threes} = $self->Threes - 1 }

  if ($self->Ones + $self->Twos + $self->Threes == 0) {
    $self->Initialize;
  }
}

1;
# vi:ai:et:sw=2 ts=2
