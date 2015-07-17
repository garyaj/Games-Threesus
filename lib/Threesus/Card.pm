# Represents a single card in the game.
package Threesus::Card;
use v5.14;
use Object::Tiny qw{
  Value # Face-value of this card: 1, 2, 3, 6, 12, 24, etc...
};

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

1;
# vi:ai:et:sw=2 ts=2

