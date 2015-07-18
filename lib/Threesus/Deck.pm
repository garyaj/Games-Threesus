# Manages a randomly-shuffled deck of card values.
package Threesus::Deck;
use strict;
use warnings;

use List::Util qw{shuffle};

my @INITIAL_CARD_VALUES = qw(1 1 1 1 2 2 2 2 3 3 3 3);

sub new {
  my $class = shift;
  my $self = {@_};
  bless $self, $class;
  $self->RebuildDeck();
  return $self;
}

sub _cardValues { return $_[0]->{_cardValues} }

# Removes and returns the next card value from the top of this Deck.
sub DrawNextCard {
  my $self = shift;
  if (scalar @{$self->_cardValues} == 0) {
    $self->RebuildDeck();
  }
  return pop @{$self->{_cardValues}};
}

sub GetCountsOfCards {
  my $self = shift;
  if (scalar @{$self->_cardValues} == 0) {
    $self->RebuildDeck();
  }
  my $ret = {};
  for my $value (@{$self->_cardValues}) {
    if (exists $ret->{$value}) {
      $ret->{$value}++;
    } else {
      $ret->{$value} = 1;
    }
  }
  return $ret;
}

# Returns a hint about what the value of the next drawn card will be.
sub PeekNextCard {
  my $self = shift;
  if (scalar @{$self->_cardValues} == 0) {
    $self->RebuildDeck();
  }
  return $self->{_cardValues}->[-1];
}

# Removes a card of the specified value from this deck.
sub RemoveCard {
  my ($self, $cardValue) = @_;
  if (scalar @{$self->_cardValues} == 0) {
    $self->RebuildDeck();
  }
  for my $i (0 .. $#{$self->_cardValues}) {
    if ($self->_cardValues->[$i] == $cardValue) {
      splice(@{$self->{_cardValues}}, $i, 1);  #remove 1 item
      last;
    }
  }
}

# Rebuilds the deck using a shuffled list of initial cards.
# Assumes that the deck is currently empty.
sub RebuildDeck {
  my $self = shift;

  push @{$self->{_cardValues}}, @INITIAL_CARD_VALUES;
  @{$self->{_cardValues}} = shuffle @{$self->{_cardValues}};
}

1;
# vi:ai:et:sw=2 ts=2

