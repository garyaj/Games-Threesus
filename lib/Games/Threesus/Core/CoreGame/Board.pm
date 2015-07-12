# Stores a snapshot of the state of the game board.
# This version is much faster than the normal Board class, but doesn't contain unique Card IDs.
package Games::Threesus::Core::CoreGame::Board;
use Moo;
use Type::Tiny qw(Str Int ArrayRef);
use strictures 1;
use namespace::clean;
use Games::Threesus::Core::Bots::FastLookups;
use Games::Threesus::Core::V2D;

# Masks used to access a particular cell in the _board variable.
use constant {
  MASK_0_0 => 0x000000000000000f,
  MASK_1_0 => 0x00000000000000f0,
  MASK_2_0 => 0x0000000000000f00,
  MASK_3_0 => 0x000000000000f000,
  MASK_0_1 => 0x00000000000f0000,
  MASK_1_1 => 0x0000000000f00000,
  MASK_2_1 => 0x000000000f000000,
  MASK_3_1 => 0x00000000f0000000,
  MASK_0_2 => 0x0000000f00000000,
  MASK_1_2 => 0x000000f000000000,
  MASK_2_2 => 0x00000f0000000000,
  MASK_3_2 => 0x0000f00000000000,
  MASK_0_3 => 0x000f000000000000,
  MASK_1_3 => 0x00f0000000000000,
  MASK_2_3 => 0x0f00000000000000,
  MASK_3_3 => 0xf000000000000000,
};

# A lookup array where the index is (x + 4*y).
use constant MASK_LOOKUPS => qw(
  MASK_0_0
  MASK_1_0
  MASK_2_0
  MASK_3_0
  MASK_0_1
  MASK_1_1
  MASK_2_1
  MASK_3_1
  MASK_0_2
  MASK_1_2
  MASK_2_2
  MASK_3_2
  MASK_0_3
  MASK_1_3
  MASK_2_3
  MASK_3_3
);

# Amount by which to right-shift a masked cell to move it to the lowest-order position.
use constant {
	SHIFT_0_0 = 0,
	SHIFT_1_0 = 4,
	SHIFT_2_0 = 8,
	SHIFT_3_0 = 12,
	SHIFT_0_1 = 16,
	SHIFT_1_1 = 20,
	SHIFT_2_1 = 24,
	SHIFT_3_1 = 28,
	SHIFT_0_2 = 32,
	SHIFT_1_2 = 36,
	SHIFT_2_2 = 40,
	SHIFT_3_2 = 44,
	SHIFT_0_3 = 48,
	SHIFT_1_3 = 52,
	SHIFT_2_3 = 56,
	SHIFT_3_3 = 60,
};

# A lookup array where the index is (x + 4*y).
use constant Shift_LOOKUPS => qw(
  SHIFT_0_0
  SHIFT_1_0
  SHIFT_2_0
  SHIFT_3_0
  SHIFT_0_1
  SHIFT_1_1
  SHIFT_2_1
  SHIFT_3_1
  SHIFT_0_2
  SHIFT_1_2
  SHIFT_2_2
  SHIFT_3_2
  SHIFT_0_3
  SHIFT_1_3
  SHIFT_2_3
  SHIFT_3_3
);

has Width  => ( is => 'ro', default => 4);
has Height => ( is => 'ro', default => 4);

has _board => ( is => 'ro', builder => '_build_board' ); # 16 spaces at 4 bits per space = 64 bits.

# A lookup array whose index is (sourceCardIndex | (destCardIndex << 4)) and whose output is the resulting index for the destination cell;
has DEST_SHIFT_RESULTS => (isa => ArrayRef[Int], is => 'ro');
# A lookup array whose index is (sourceCardIndex | (destCardIndex << 4)) and whose output is the resulting index for the source cell.
has SOURCE_SHIFT_RESULTS => (isa => ArrayRef[Int], is => 'ro');

has FLU => (is => 'ro');

# Static constructor to initialize lookup arrays.
sub Initialise {
  my $self = shift;
  for my $sourceIndex ( 0 .. $#{$self->FLU->CARD_INDEX_TO_VALUE}) {
    for my $destIndex ( 0 .. $#{$self->FLU->CARD_INDEX_TO_VALUE}) {
      my ($outputSourceIndex, $outputDestIndex);

      if ($destIndex == 0) {
        $outputSourceIndex = 0;
        $outputDestIndex = $sourceIndex;
      } elsif ($sourceIndex == 0) {
        $outputSourceIndex = 0;
        $outputDestIndex = $destIndex;
      } elsif (($sourceIndex == 1 && $destIndex == 2) || ($sourceIndex == 2 && $destIndex == 1)) {
        $outputSourceIndex = 0;
        $outputDestIndex = 3;
      } elsif ($sourceIndex >= 3 && $sourceIndex == $destIndex) {
        $outputSourceIndex = 0;
        $outputDestIndex = $sourceIndex + 1; # Inceasing the index one means doubling the face value.
      } else {
        $outputSourceIndex = $sourceIndex;
        $outputDestIndex = $destIndex;
      }

      my $lookupArrayIndex = $sourceIndex | ($destIndex << 4);
      $self->DEST_SHIFT_RESULTS->[$lookupArrayIndex] = $outputDestIndex;
      $self->SOURCE_SHIFT_RESULTS->[$lookupArrayIndex] = $outputSourceIndex;
    }
  }
}

# Initializes a new FastBoard from the specified Board object.
sub _build_board {
  my ($self, $board) = @_;
  die "board must not be null" unless $board;

  $self->_board = '';
  for my $x ( 0 .. $self->Width-1) {
    for my $y ( 0 .. $self->Height-1) {
      my $card = Card->new($board[$x, $y]);
      $self->SetCardIndex($x, $y, $self->FLU->CARD_VALUE_TO_INDEX[$card ? $card->Value : 0]);
    }
  }
}

# Returns whether this FastBoard is equal to the specified Board.
sub Equals {
 my ($self, $board) = @_;
  return unless $board;

  for my $x = (0 .. $self->Width-1) {
    for my $y = (0 .. $self->Height-1) {
      my $ourCardValue = $self->FLU->CARD_INDEX_TO_VALUE[$self->GetCardIndex($x, $y)];
      my $theirCard = Card->new($board[$x, $y]);
      my $theirCardvalue = $theirCard ? $theirCard->Value : 0;
      return if ($ourCardValue != $theirCardvalue);
    }
  }
  return 1;
}

# Returns the hash code for the current state of this board.
sub GetHashCode {
  my ($self) = @_;
  return $self->_board->GetHashCode;
}

# Returns the card index of the card at the specified cell.
# 0 means no card there. Use FastLookups(FLU) to look up values associated with the index.
sub GetCardIndex {
  my ($self, $x, $y) = @_;
  my $lookupIndex = $x + 4 * $y;
  return ($self->_board & MASK_LOOKUPS[$lookupIndex]) >> SHIFT_LOOKUPS[$lookupIndex];
}

# Returns the card index of the card at the specified cell.
# 0 means no card there. Use FastLookups to look up values associated with the index.
sub GetCardIndexFromCell {
  my ($self, $cell) = @_;
  return $self->GetCardIndex($cell->X, $cell->Y);
}

# Sets the card index of the card at the specified cell.
# 0 means no card there. Use FastLookups to look up values associated with the index.
sub SetCardIndex
{
  my ($self, $x, $y, $cardIndex) = @_;
  my $lookupIndex = $x + 4 * $y;
  $self->_board = ($self->_board & ~MASK_LOOKUPS[$lookupIndex]) | ($cardIndex << SHIFT_LOOKUPS[$lookupIndex]);
}

# Sets the card index of the card at the specified cell.
# 0 means no card there. Use FastLookups to look up values associated with the index.
sub SetCardIndexFromCell {
  my ($self, $cell, $cardIndex) = @_;
  $self->SetCardIndex($cell->X, $cell->Y, $cardIndex);
}

# Returns the total point score of the current board.
sub GetTotalScore {
  my ($self) = @_;
  my $total = 0;
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_0_0) >> SHIFT_0_0];
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_0_1) >> SHIFT_0_1];
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_0_2) >> SHIFT_0_2];
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_0_3) >> SHIFT_0_3];
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_1_0) >> SHIFT_1_0];
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_1_1) >> SHIFT_1_1];
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_1_2) >> SHIFT_1_2];
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_1_3) >> SHIFT_1_3];
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_2_0) >> SHIFT_2_0];
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_2_1) >> SHIFT_2_1];
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_2_2) >> SHIFT_2_2];
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_2_3) >> SHIFT_2_3];
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_3_0) >> SHIFT_3_0];
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_3_1) >> SHIFT_3_1];
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_3_2) >> SHIFT_3_2];
  $total += $self->FLU->CARD_INDEX_TO_POINTS[($self->_board & MASK_3_3) >> SHIFT_3_3];
  return $total;
}

# Gets the card index of the highest-valued card on the board.
sub GetMaxCardIndex {
  my $self = shift;
  my $max = 0;
  for my $x ( 0 .. $self->Width) {
    for my $y ( 0 .. $self->Height) {
      my $ix = $self->GetCardIndex($x, $y);
      $max = $ix > $max ? $ix : $max;
    }
  }
  return $max;
}

# Returns the string representation of the current state of this board.
sub ToString {
  my $self = shift;
  my @vals;
  my $str = '';
  for my $y ( 0 .. $self->Height-1) {
    for my $x ( 0 .. $self->Width-1) {
      my $cardIndex = $self->GetCardIndex($x, $y);
      my $value = $self->FLU->CARD_INDEX_TO_VALUE[$cardIndex];
      push @vals, $value;
    }
    $str .= join ", ", @vals;
    $str .= "\n";
    @vals = ();
  }
  return $str;
}

# Modifies this board in-place by shifting those cards that can be shifted or merged in the specified direction.
# <param name="newCardCells">The possible locations for a new card will be added to this array.</param>
# <returns>Whether anything was able to be shifted.</returns>
sub ShiftInPlace {
  my ($self, $dir, $newCardCells) = @_;
  my $oldBoard = $self->_board;
  given ($dir) {
    $self->ShiftLeft($newCardCells)  when /Left/;
    $self->ShiftRight($newCardCells) when /Right/;
    $self->ShiftUp($newCardCells)    when /Up/;
    $self->ShiftDown($newCardCells)  when /Down/;
    default { die "Unknown ShiftDirection '$dir'.");
  }
  return $oldBoard ne $self->_board;
}

# Shifts this board in-place to the left.
sub ShiftLeft {
  my($self, $newCardCells) = @_;
  {
    my $prevBoard = $self->_board;

    my $cell1Index = ($self->_board & MASK_0_0) >> SHIFT_0_0;
    my $cell2Index = ($self->_board & MASK_1_0) >> SHIFT_1_0;

    my $arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $cell3Index = ($self->_board & MASK_2_0) >> SHIFT_2_0;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $cell4Index = ($self->_board & MASK_3_0) >> SHIFT_3_0;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_0_0 | MASK_1_0 | MASK_2_0 | MASK_3_0)) |
             ($cell1Index << SHIFT_0_0) |
             ($cell2Index << SHIFT_1_0) |
             ($cell3Index << SHIFT_2_0) |
             ($cell4Index << SHIFT_3_0);
    if ($prevBoard ne $self->_board) {
      $newCardCells->[0] = V2D->new(X => 3, Y => 0);
    } else {
      $newCardCells->[0] = V2D->(X => -1, Y => -1);
    }
  }

  {
    my $$prevBoard = $self->_board;

    my $$cell1Index = ($self->_board & MASK_0_1) >> SHIFT_0_1;
    my $$cell2Index = ($self->_board & MASK_1_1) >> SHIFT_1_1;

    my $$arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell3Index = ($self->_board & MASK_2_1) >> SHIFT_2_1;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell4Index = ($self->_board & MASK_3_1) >> SHIFT_3_1;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_0_1 | MASK_1_1 | MASK_2_1 | MASK_3_1)) |
             ($cell1Index << SHIFT_0_1) |
             ($cell2Index << SHIFT_1_1) |
             ($cell3Index << SHIFT_2_1) |
             ($cell4Index << SHIFT_3_1);
    if ($prevBoard != $self->_board) {
      $newCardCells->[1] = V2D->new(X => 3, Y => 1);
    } else {
      $newCardCells->[1] = V2D->(X => -1, Y => -1);
    }
  }

  {
    my $$prevBoard = $self->_board;

    my $$cell1Index = ($self->_board & MASK_0_2) >> SHIFT_0_2;
    my $$cell2Index = ($self->_board & MASK_1_2) >> SHIFT_1_2;

    my $$arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell3Index = ($self->_board & MASK_2_2) >> SHIFT_2_2;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell4Index = ($self->_board & MASK_3_2) >> SHIFT_3_2;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_0_2 | MASK_1_2 | MASK_2_2 | MASK_3_2)) |
             ($cell1Index << SHIFT_0_2) |
             ($cell2Index << SHIFT_1_2) |
             ($cell3Index << SHIFT_2_2) |
             ($cell4Index << SHIFT_3_2);
    if ($prevBoard != $self->_board) {
      $newCardCells->[2] = V2D->new(X => 3, Y => 2);
    } else {
      $newCardCells->[2] = V2D->(X => -1, Y => -1);
    }
  }

  {
    my $$prevBoard = $self->_board;

    my $$cell1Index = ($self->_board & MASK_0_3) >> SHIFT_0_3;
    my $$cell2Index = ($self->_board & MASK_1_3) >> SHIFT_1_3;

    my $$arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell3Index = ($self->_board & MASK_2_3) >> SHIFT_2_3;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell4Index = ($self->_board & MASK_3_3) >> SHIFT_3_3;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_0_3 | MASK_1_3 | MASK_2_3 | MASK_3_3)) |
             ($cell1Index << SHIFT_0_3) |
             ($cell2Index << SHIFT_1_3) |
             ($cell3Index << SHIFT_2_3) |
             ($cell4Index << SHIFT_3_3);
    if ($prevBoard != $self->_board) {
      $newCardCells->[3] = V2D->new(X => 3, Y => 3);
    } else {
      $newCardCells->[3] = V2D->(X => -1, Y => -1);
    }
  }
}

# Shifts this board in-place to the right.
sub ShiftRight {
  my($self, $$newCardCells->) = @_;
  {
    my $$prevBoard = $self->_board;

    my $$cell1Index = ($self->_board & MASK_3_0) >> SHIFT_3_0;
    my $$cell2Index = ($self->_board & MASK_2_0) >> SHIFT_2_0;

    my $$arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell3Index = ($self->_board & MASK_1_0) >> SHIFT_1_0;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell4Index = ($self->_board & MASK_0_0) >> SHIFT_0_0;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_3_0 | MASK_2_0 | MASK_1_0 | MASK_0_0)) |
             ($cell1Index << SHIFT_3_0) |
             ($cell2Index << SHIFT_2_0) |
             ($cell3Index << SHIFT_1_0) |
             ($cell4Index << SHIFT_0_0);
    if ($prevBoard != $self->_board) {
      $newCardCells->[0] = V2D->new(X => 0, Y => 0);
    } else {
      $newCardCells->[0] = V2D->(X => -1, Y => -1);
    }
  }

  {
    my $$prevBoard = $self->_board;

    my $$cell1Index = ($self->_board & MASK_3_1) >> SHIFT_3_1;
    my $$cell2Index = ($self->_board & MASK_2_1) >> SHIFT_2_1;

    my $$arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell3Index = ($self->_board & MASK_1_1) >> SHIFT_1_1;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell4Index = ($self->_board & MASK_0_1) >> SHIFT_0_1;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_3_1 | MASK_2_1 | MASK_1_1 | MASK_0_1)) |
             ($cell1Index << SHIFT_3_1) |
             ($cell2Index << SHIFT_2_1) |
             ($cell3Index << SHIFT_1_1) |
             ($cell4Index << SHIFT_0_1);
    if ($prevBoard != $self->_board) {
      $newCardCells->[1] = V2D->new(X => 0, Y => 1);
    } else {
      $newCardCells->[1] = V2D->(X => -1, Y => -1);
    }
  }

  {
    my $$prevBoard = $self->_board;

    my $$cell1Index = ($self->_board & MASK_3_2) >> SHIFT_3_2;
    my $$cell2Index = ($self->_board & MASK_2_2) >> SHIFT_2_2;

    my $$arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell3Index = ($self->_board & MASK_1_2) >> SHIFT_1_2;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell4Index = ($self->_board & MASK_0_2) >> SHIFT_0_2;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_3_2 | MASK_2_2 | MASK_1_2 | MASK_0_2)) |
             ($cell1Index << SHIFT_3_2) |
             ($cell2Index << SHIFT_2_2) |
             ($cell3Index << SHIFT_1_2) |
             ($cell4Index << SHIFT_0_2);
    if ($prevBoard != $self->_board) {
      $newCardCells->[2] = V2D->new(X => 0, Y => 2);
    } else {
      $newCardCells->[2] = V2D->(X => -1, Y => -1);
    }
  }

  {
    my $$prevBoard = $self->_board;

    my $$cell1Index = ($self->_board & MASK_3_3) >> SHIFT_3_3;
    my $$cell2Index = ($self->_board & MASK_2_3) >> SHIFT_2_3;

    my $$arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell3Index = ($self->_board & MASK_1_3) >> SHIFT_1_3;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell4Index = ($self->_board & MASK_0_3) >> SHIFT_0_3;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_3_3 | MASK_2_3 | MASK_1_3 | MASK_0_3)) |
             ($cell1Index << SHIFT_3_3) |
             ($cell2Index << SHIFT_2_3) |
             ($cell3Index << SHIFT_1_3) |
             ($cell4Index << SHIFT_0_3);
    if ($prevBoard != $self->_board) {
      $newCardCells->[3] = V2D->new(X => 0, Y => 3);
    } else {
      $newCardCells->[3] = V2D->(X => -1, Y => -1);
    }
  }
}

# Shifts this board in-place up.
sub ShiftUp {
  my($self, $$newCardCells->) = @_;
  {
    my $$prevBoard = $self->_board;

    my $$cell1Index = ($self->_board & MASK_0_0) >> SHIFT_0_0;
    my $$cell2Index = ($self->_board & MASK_0_1) >> SHIFT_0_1;

    my $$arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell3Index = ($self->_board & MASK_0_2) >> SHIFT_0_2;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell4Index = ($self->_board & MASK_0_3) >> SHIFT_0_3;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_0_0 | MASK_0_1 | MASK_0_2 | MASK_0_3)) |
             ($cell1Index << SHIFT_0_0) |
             ($cell2Index << SHIFT_0_1) |
             ($cell3Index << SHIFT_0_2) |
             ($cell4Index << SHIFT_0_3);
    if ($prevBoard != $self->_board) {
      $newCardCells->[0] = V2D->new(X => 0, Y => 3);
    } else {
      $newCardCells->[0] = V2D->(X => -1, Y => -1);
    }
  }

  {
    my $$prevBoard = $self->_board;

    my $$cell1Index = ($self->_board & MASK_1_0) >> SHIFT_1_0;
    my $$cell2Index = ($self->_board & MASK_1_1) >> SHIFT_1_1;

    my $$arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell3Index = ($self->_board & MASK_1_2) >> SHIFT_1_2;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell4Index = ($self->_board & MASK_1_3) >> SHIFT_1_3;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_1_0 | MASK_1_1 | MASK_1_2 | MASK_1_3)) |
             ($cell1Index << SHIFT_1_0) |
             ($cell2Index << SHIFT_1_1) |
             ($cell3Index << SHIFT_1_2) |
             ($cell4Index << SHIFT_1_3);
    if ($prevBoard != $self->_board) {
      $newCardCells->[1] = V2D->new(X => 1, Y => 3);
    } else {
      $newCardCells->[1] = V2D->(X => -1, Y => -1);
    }
  }

  {
    my $$prevBoard = $self->_board;

    my $$cell1Index = ($self->_board & MASK_2_0) >> SHIFT_2_0;
    my $$cell2Index = ($self->_board & MASK_2_1) >> SHIFT_2_1;

    my $$arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell3Index = ($self->_board & MASK_2_2) >> SHIFT_2_2;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell4Index = ($self->_board & MASK_2_3) >> SHIFT_2_3;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_2_0 | MASK_2_1 | MASK_2_2 | MASK_2_3)) |
             ($cell1Index << SHIFT_2_0) |
             ($cell2Index << SHIFT_2_1) |
             ($cell3Index << SHIFT_2_2) |
             ($cell4Index << SHIFT_2_3);
    if ($prevBoard != $self->_board) {
      $newCardCells->[2] = V2D->new(X => 2, Y => 3);
    } else {
      $newCardCells->[2] = V2D->(X => -1, Y => -1);
    }
  }

  {
    my $$prevBoard = $self->_board;

    my $$cell1Index = ($self->_board & MASK_3_0) >> SHIFT_3_0;
    my $$cell2Index = ($self->_board & MASK_3_1) >> SHIFT_3_1;

    my $$arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell3Index = ($self->_board & MASK_3_2) >> SHIFT_3_2;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell4Index = ($self->_board & MASK_3_3) >> SHIFT_3_3;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_3_0 | MASK_3_1 | MASK_3_2 | MASK_3_3)) |
             ($cell1Index << SHIFT_3_0) |
             ($cell2Index << SHIFT_3_1) |
             ($cell3Index << SHIFT_3_2) |
             ($cell4Index << SHIFT_3_3);
    if ($prevBoard != $self->_board) {
      $newCardCells->[3] = V2D->new(X => 3, Y => 3);
    } else {
      $newCardCells->[3] = V2D->(X => -1, Y => -1);
    }
  }
}

# Shifts this board in-place down.
sub ShiftDown {
  my($self, $$newCardCells->) = @_;
  {
    my $$prevBoard = $self->_board;

    my $$cell1Index = ($self->_board & MASK_0_3) >> SHIFT_0_3;
    my $$cell2Index = ($self->_board & MASK_0_2) >> SHIFT_0_2;

    my $$arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell3Index = ($self->_board & MASK_0_1) >> SHIFT_0_1;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell4Index = ($self->_board & MASK_0_0) >> SHIFT_0_0;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_0_3 | MASK_0_2 | MASK_0_1 | MASK_0_0)) |
             ($cell1Index << SHIFT_0_3) |
             ($cell2Index << SHIFT_0_2) |
             ($cell3Index << SHIFT_0_1) |
             ($cell4Index << SHIFT_0_0);
    if ($prevBoard != $self->_board) {
      $newCardCells->[0] = V2D->new(X => 0, Y => 0);
    } else {
      $newCardCells->[0] = V2D->(X => -1, Y => -1);
    }
  }

  {
    my $$prevBoard = $self->_board;

    my $$cell1Index = ($self->_board & MASK_1_3) >> SHIFT_1_3;
    my $$cell2Index = ($self->_board & MASK_1_2) >> SHIFT_1_2;

    my $$arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell3Index = ($self->_board & MASK_1_1) >> SHIFT_1_1;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell4Index = ($self->_board & MASK_1_0) >> SHIFT_1_0;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_1_3 | MASK_1_2 | MASK_1_1 | MASK_1_0)) |
             ($cell1Index << SHIFT_1_3) |
             ($cell2Index << SHIFT_1_2) |
             ($cell3Index << SHIFT_1_1) |
             ($cell4Index << SHIFT_1_0);
    if ($prevBoard != $self->_board) {
      $newCardCells->[1] = V2D->new(X => 1, Y => 0);
    } else {
      $newCardCells->[1] = V2D->(X => -1, Y => -1);
    }
  }

  {
    my $$prevBoard = $self->_board;

    my $$cell1Index = ($self->_board & MASK_2_3) >> SHIFT_2_3;
    my $$cell2Index = ($self->_board & MASK_2_2) >> SHIFT_2_2;

    my $$arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell3Index = ($self->_board & MASK_2_1) >> SHIFT_2_1;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell4Index = ($self->_board & MASK_2_0) >> SHIFT_2_0;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_2_3 | MASK_2_2 | MASK_2_1 | MASK_2_0)) |
             ($cell1Index << SHIFT_2_3) |
             ($cell2Index << SHIFT_2_2) |
             ($cell3Index << SHIFT_2_1) |
             ($cell4Index << SHIFT_2_0);
    if ($prevBoard != $self->_board) {
      $newCardCells->[2] = V2D->new(X => 2, Y => 0);
    } else {
      $newCardCells->[2] = V2D->(X => -1, Y => -1);
    }
  }

  {
    my $$prevBoard = $self->_board;

    my $$cell1Index = ($self->_board & MASK_3_3) >> SHIFT_3_3;
    my $$cell2Index = ($self->_board & MASK_3_2) >> SHIFT_3_2;

    my $$arrayLookup = $cell2Index | ($cell1Index << 4);
    $cell1Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell2Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell3Index = ($self->_board & MASK_3_1) >> SHIFT_3_1;
    $arrayLookup = $cell3Index | ($cell2Index << 4);
    $cell2Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell3Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    my $$cell4Index = ($self->_board & MASK_3_0) >> SHIFT_3_0;
    $arrayLookup = $cell4Index | ($cell3Index << 4);
    $cell3Index = $self->DEST_SHIFT_RESULTS[$arrayLookup];
    $cell4Index = $self->SOURCE_SHIFT_RESULTS[$arrayLookup];

    $self->_board = ($self->_board & ~(MASK_3_3 | MASK_3_2 | MASK_3_1 | MASK_3_0)) |
             ($cell1Index << SHIFT_3_3) |
             ($cell2Index << SHIFT_3_2) |
             ($cell3Index << SHIFT_3_1) |
             ($cell4Index << SHIFT_3_0);
    if ($prevBoard != $self->_board) {
      $newCardCells->[3] = V2D->new(X => 3, Y => 0);
    } else {
      $newCardCells->[3] = V2D->new(X => -1, Y => -1);
    }
  }
}

# Returns whether the specified cards can merge together.
# Assumes that neither card index is 0.
sub CanCardsMerge {
  my ($self, $sourceCardIndex, $destCardIndex) = @_;
  my $arrayLookup = $sourceCardIndex | ($destCardIndex << 4);
  return $self->DEST_SHIFT_RESULTS[$arrayLookup] != $destCardIndex;
}

1;
# vi:ai:et:sw=2 ts=2

