# Contains fast lookup arrays by card number.
package Games::Threesus::Core::Bots::FastLookups;
use Moo;
use Tiny::Types qw(Str Int ArrayRef);
use strictures 1;
use namespace::clean;

# Looks up the face value of a card by its 4-bit index.
use constant CARD_INDEX_TO_VALUE => qw (
  0
  1
  2
  3
  6
  12
  24
  48
  96
  192
  384
  768
  1536
  3072
  6144
  12288
);

# Looks up the total point value of a card by its 4-bit index.
use constant CARD_INDEX_TO_POINTS => qw(
  0
  0
  0
  3
  9
  27
  81
  243
  729
  2187
  6561
  19683
  59049
  177147
  531441
  1594323
);

# Looks up the card index by its face value.
has CARD_VALUE_TO_INDEX => (is => 'ro', isa => HashRef, builder => '_build_fast_lu');

# Initializes lookups.
sub _build_fast_lu {
  my $self = shift;
  for my $cardIndex ( 0 .. length(CARD_INDEX_TO_VALUE)-1) {
    $self->CARD_VALUE_TO_INDEX->{CARD_INDEX_TO_VALUE[$cardIndex]} = $cardIndex;
  }
}
1;
# vi:ai:et:sw=2 ts=2

