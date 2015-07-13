# Manages a randomly-shuffled deck of card values.
package Games::Threesus::Core::CoreGame::Deck;
use v5.14;
use Moo;
use MooX::Types::MooseLike::Base qw(:all);
use strictures 1;
use namespace::clean;

use constant INITIAL_CARD_VALUES => qw(1 1 1 1 2 2 2 2 3 3 3 3);

has _cardValues => (isa => ArrayRef[InstanceOf['Card']], is => 'rw', default => sub {[]});

# Creates a new Deck with the initial set of cards, and shuffles them using the specified random number generator.

# Removes and returns the next card value from the top of this Deck.
sub DrawNextCard {
  my $self = shift;
  if ($self->_cardValues == 0) {
    $self->RebuildDeck();
  }
  return pop @$self->_cardValues;
}

# Returns a hint about what the value of the next drawn card will be.
sub PeekNextCard {
  my $self = shift;
  if ($self->_cardValues == 0) {
    $self->RebuildDeck();
  }
  return $self->_cardValues->[-1];
}

# Returns a dictionary with card values as keys for the number of cards of that value.
sub GetCountsOfCards {
  my $self = shift;
  if ($self->_cardValues == 0) {
    $self->RebuildDeck();
  }

  my $ret = {};
  for my $i (0 .. $self->_cardValues) {
    my $value = $self->_cardValues->[$i];
    my $count;
    if (exists $ret->{$value}) {
      $ret->{$value}++;
    } else {
      $ret->{$value} = 1;
    }
  }
  return $ret;
}

# Removes a card of the specified value from this deck.
sub RemoveCard {
  my ($self, $cardValue) = @_;
  if ($self->_cardValues == 0) {
    $self->RebuildDeck();
  }

  $self->_cardValues->Remove($cardValue);
}

# Rebuilds the deck using a shuffled list of initial cards.
# Assumes that the deck is currently empty.
sub RebuildDeck {
  my $self = shift;
  #Debug.Assert(_cardValues.Count == 0);

  $self->_cardValues(INITIAL_CARD_VALUES);
  fisher_yates_shuffle($self->_cardValues);
}

# fisher_yates_shuffle( \@array ) : generate a random permutation
# of @array in place
sub fisher_yates_shuffle {
  my $array = shift;
  my $i;
  for ($i = @$array; --$i; ) {
    my $j = int rand ($i+1);
    next if $i == $j;
    @$array[$i,$j] = @$array[$j,$i];
  }
}

1;
# vi:ai:et:sw=2 ts=2

