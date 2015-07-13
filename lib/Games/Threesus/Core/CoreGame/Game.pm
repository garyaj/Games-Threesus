# Manages the current state and rules of the game.
package Games::Threesus::Core::CoreGame::Game;
use v5.14;
use Moo;
use strictures 1;
use namespace::clean;

use constant NUM_INITIAL_CARDS => 9;
use constant BONUS_CARD_CHANCE => 1.0 / 21.0;
use enum qw(One Two Three Bonus);

has _rand => (is => 'ro');
has _deck => (is => 'ro');
has _board => (is => 'ro');
has _prevBoard => (is => 'ro');
has _tempBoard => (is => 'ro');
has _nextCardID => (is => 'ro', default => 0);
has _nextBonusCard => (is => 'ro');

# Gets the current state of the game board.
sub CurrentBoard {
  my ($self) = @_;
  return $self->_board;
}

# Gets the previous state of the game board before the last shift.
sub PreviousBoard {
  my ($self) = @_;
  return $self->_prevBoard;
}

# Gets the current state of the game card deck.
sub CurrentDeck {
  my ($self) = @_;
  return $self->_deck;
}

# Returns a hint that indicates the value of the next card to be added to the board.
sub NextCardHint {
  my ($self) = @_;
  my $nextCardValue = $self->_nextBonusCard // $self->_deck->PeekNextCard;
  given ($nextCardValue) {
    when (/^1/) { return One }
    when (/^2/) { return Two }
    when (/^3/) { return Three }
    default {return Bonus}
  }
}

# Creates a new Game that uses the specified random number generator.
sub Initialize {
  my ($self) = @_;
  $self->_deck = Deck->new;
  $self->_board = Board->new;

  InitializeBoard();

  $self->_prevBoard = Board->new->CopyFrom(_board);
  $self->_tempboard = Board->new;
}

# Shifts the game board in the specified direction, merging cards where possible.
# <returns>Whether any cards were actually shifted.</returns>
sub Shift {
  my ($self, $dir) = @_;
  $self->_tempBoard = $self->_board;
  my $newCardCells = [];
  my $shifted = $self->_board->ShiftInPlace($dir, $newCardCells);
  if ($shifted) {
    my $newCardCell = $newCardCells->[rand(scalar @$newCardCells)];
    $self->_board[$newCardCell] = $self->DrawNextCard;

    $self->_prevBoard = $self->_tempBoard;
  }
  return $shifted;
}

# Initializes the game's Board with its starting cards.
sub InitializeBoard {
  my ($self) = @_;
  for (1 .. NUM_INITIAL_CARDS) {
    my $cell = $self->GetRandomEmptyCell;
    $self->_board[$cell] = $self->DrawNextCard;
  }
}

# Returns a random empty cell on the game board.
sub GetRandomEmptyCell {
  my ($self) = @_;
  my $ret;
  do {
    $ret = V2D->new(
      X => rand( $self->_board->Width),
      Y => rand( $self->_board->Height)
    );
  }
  while($self->_board[$ret]);
  return $ret;
}

# Draws the next card to add to the board.
sub DrawNextCard {
  my ($self) = @_;
  my $cardValue = $self->_nextBonusCard // $self->_deck->DrawNextCard;

  # Should the next card be a bonus card?
  my $maxCardValue = $self->_board->GetMaxCardValue;
  if ($maxCardValue >= 48 && rand < BONUS_CARD_CHANCE) {
    my $possibleBonusCards = $self->GetPossibleBonusCards($maxCardValue));
    $self->_nextBonusCard = $possibleBonusCards[rand(scalar @{$possibleBonusCards})];
  } else {
    $self->_nextBonusCard = 0;
  }

  return $cardValue;
}

# Returns the possible bonus cards for the specified board.
sub GetPossibleBonusCards {
  my ($self, $maxCardValue) = @_;
  my $maxBonusCard = $maxCardValue / 8;
  my $val = 6;
  while ($val <= $maxBonusCard) { $val *= 2; }
  return $val;
}

# Returns the possible bonus cards for the specified board.
sub GetPossibleBonusCardIndexes {
  my ($self, $maxCardIndex, $cardIndexes) = @_;
  my $maxBonusCardIndex = $maxCardIndex - 3;
  for (my $cardIndex = 4; $cardIndex <= $maxBonusCardIndex; $cardIndex++) {
    push @{$cardIndexes}, $cardIndex;
  }
}

1;
# vi:ai:et:sw=2 ts=2

