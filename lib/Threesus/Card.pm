# Represents a single card in the game.
package Games::Threesus::Core::CoreGame::Card;
use v5.14;
use Moo;
use strictures 1;
use namespace::clean;
# use UUID::Tiny ':std';

# Face-value of this card.
# 1, 2, 3, 6, 12, 24, etc...
has Value => ( is => 'ro' );

# ID of this card that is unique within a single game of Threes.
# This number can be used to track how a card was moved between consecutive turns.
has UniqueID => ( is => 'ro' );

# Gets the score points that this card is worth at the end of the game.
sub Score {
  my $self = shift;
  my $valOver3 = int($self->Value / 3);
  my $exp = int(log($valOver3) / log(2)) + 1;
  return int(3**$exp);
}

# Returns whether this Card is equal to the specified Card, including having the same UniqueID.
sub Equals {
  my($self, $card) = @_;
  return $card and
         $self->Value == $card->Value and
         $self->UniqueID eq $card->UniqueID;
}

# Returns the string representation of this Card.
sub ToString {
  my $self = shift;
  return "{Value=".$self->Value.",UID=".$self->UniqueID."}";
}

# Returns whether this Card can be merged with the specified other card.
# The merge relationship between two cards is always symmetrical.
sub CanMergeWith {
  my ($self, $other) = @_;
  if ($self->Value == 1) {
    return $other->Value == 2;
  } elsif ($self-> Value == 2) {
    return $other->Value == 1;
  } else {
    return $self->Value == $other->Value;
  }
}

# Gets the result of merging this Card with the specified Card.
# Returns null if the merge cannot happen.
# The UniqueID of the new card will be the UniqueID of this Card.
sub GetMergedWith {
  my ($self, $other) = @_;
  if ($self->Value == 1) {
    return $other->Value == 2 ? Card->new(Value => 3, UniqueID => $self->UniqueID ) : '';
  } elsif ($self->Value == 2) {
    return $other->Value == 1 ? Card->new(Value => 3, UniqueID => $self->UniqueID ) : '';
  } else {
    return $self->Value == $other->Value ?
      Card->new(Value => $self->Value * 2, UniqueID => $self->UniqueID ) : '';
  }
}

1;
# vi:ai:et:sw=2 ts=2

