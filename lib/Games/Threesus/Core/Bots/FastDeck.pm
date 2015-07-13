# Stores count totals of the current deck for the purpose of counting cards. 
package Games::Threesus::Core::Bots::FastDeck;
use v5.14;
use Moo;
use MooX::Types::MooseLike::Base qw(:all);
use strictures 1;
use namespace::clean;

has Ones   => ( is => 'rw' );
has Twos   => ( is => 'rw' );
has Threes => ( is => 'rw' );
has cardCounts => (isa => HashRef[Int], is => 'rw', default => sub {[]});


# Initializes the counts in a new FastDeck to the card counts in the specified Deck.
sub InitFromDeck {
  my ($self, $deck) = @_;
  die "deck must not be null" unless $deck;

  $self->cardCounts($deck->GetCountsOfCards);
  $self->Ones($self->cardCounts->{1});
  $self->Twos($self->cardCounts->{2});
  $self->Threes($self->cardCounts->{3});
}

# Initializes the card counts to their full-deck values.
sub Initialize {
  my $self = shift;
  $self->Ones(4);
  $self->Twos(4);
  $self->Threes(4);
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
  given ($cardIndex) {
    $self->Ones($self->Ones-1)     when ($cardIndex == 1);
    $self->Twos($self->Twos-1)     when ($cardIndex == 2);
    $self->Threes($self->Threes-1) when ($cardIndex == 3);
  }

  if($self->Ones + $self->Twos + $self->Threes == 0) {
    $self->Initialize;
  }
}

1;
# vi:ai:et:sw=2 ts=2
