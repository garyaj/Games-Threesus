# Manages the current state and rules of the game.
package Threesus::Game;
use v5.14;
use Object::Tiny qw{
	deck
	board
	prevBoard
	tempBoard
	nextBonusCard
};
use Threesus::Board;

my $NUM_INITIAL_CARDS = 9;
my $BONUS_CARD_CHANCE = 1.0 / 21.0;
use enum qw{Zero One Two Three Bonus};

# Gets the current state of the game board.
sub CurrentBoard {
  my ($self) = @_;
  return $self->board;
}

# Gets the previous state of the game board before the last shift.
sub PreviousBoard {
  my ($self) = @_;
  return $self->prevBoard;
}

# Gets the current state of the game card deck.
sub CurrentDeck {
  my ($self) = @_;
  return $self->deck;
}

# Returns a hint that indicates the value of the next card to be added to the board.
sub NextCardHint {
  my ($self) = @_;
  my $nextCardValue = $self->nextBonusCard // $self->deck->PeekNextCard;
  if    ($nextCardValue == 1) { return One }
  elsif ($nextCardValue == 2) { return Two }
  elsif ($nextCardValue == 3) { return Three }
  else  {return Bonus}
}

# Creates a new Game that uses the specified random number generator.
sub Initialize {
  my ($self) = @_;
  $self->deck = Threesus::Deck->new;
  $self->board = Threesus::Board->new;

  InitializeBoard();

  $self->prevBoard = Threesus::Board->new->CopyFrom($self->board);
  $self->_tempboard = Threesus::Board->new;
}

# Shifts the game board in the specified direction, merging cards where possible.
# <returns>Whether any cards were actually shifted.</returns>
sub Shift {
  my ($self, $dir) = @_;
  $self->tempBoard = $self->board;
  my $newCardCells = [];
  my $shifted = $self->board->ShiftInPlace($dir, $newCardCells);
  if ($shifted) {
    my $newCardCell = $newCardCells->[rand(scalar @$newCardCells)];
    vec($self->board->{_board}, $newCardCell->X + $newCardCell->Y * 4, 4) = $self->DrawNextCard;

    $self->prevBoard = $self->tempBoard;
  }
  return $shifted;
}

# Initializes the game's Board with its starting cards.
sub InitializeBoard {
  my ($self) = @_;
  for (1 .. $NUM_INITIAL_CARDS) {
    my $cell = $self->GetRandomEmptyCell;
    vec($self->board->{_board}, $cell->X + 4 * $cell->Y, 4) = $self->DrawNextCard;
  }
}

# Returns a random empty cell on the game board.
sub GetRandomEmptyCell {
  my ($self) = @_;
  my $ret;
  do {
    $ret = V2D->new(
      X => rand( $self->board->Width),
      Y => rand( $self->board->Height)
    );
  } while(
    vec($self->board->{_board}, $ret->X + 4 * $ret->Y, 4) != 0
  );
  return $ret;
}

# Draws the next card to add to the board.
sub DrawNextCard {
  my ($self) = @_;
  my $cardValue = $self->nextBonusCard // $self->deck->DrawNextCard;

  # Should the next card be a bonus card?
  my $maxCardValue = $self->board->GetMaxCardValue;
  if ($maxCardValue >= 48 && (rand() < $BONUS_CARD_CHANCE)) {
    my $possibleBonusCards = $self->GetPossibleBonusCards($maxCardValue);
    $self->nextBonusCard = $possibleBonusCards->[rand(scalar @{$possibleBonusCards})];
  } else {
    $self->nextBonusCard = 0;
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
  my ($self, $maxCardIndex) = @_;
  my $cardIndexes;
  my $maxBonusCardIndex = $maxCardIndex - 3;
  for (4 .. $maxBonusCardIndex) {
    push @{$cardIndexes}, $_;
  }
}

1;
# vi:ai:et:sw=2 ts=2

