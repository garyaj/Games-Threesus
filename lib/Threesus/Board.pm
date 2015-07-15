# Stores a snapshot of the state of the game board.
# This version is much faster than the normal Board class, but doesn't contain unique Card IDs.
package Threesus::Board;
use v5.14;
use Moo;
use Types::Standard qw(Str Int ArrayRef HashRef);
use strictures 1;
use namespace::clean;
use Threesus::V2D;

# Contains fast lookup arrays by card number.
# Looks up the face value of a card by its 4-bit index.
use constant CARD_INDEX_TO_VALUE => qw(
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

has Width  => ( is => 'ro', default => 4);
has Height => ( is => 'ro', default => 4);

has _board => ( is => 'rw', isa => Str, default => pack("C8", 0)); # 8 bytes = 16 nibbles at 4 bits per nibble = 64 bits.

# A lookup array whose index is (sourceCardIndex | (destCardIndex << 4)) and whose output is the resulting index for the destination cell;
has DEST_SHIFT_RESULTS => (is => 'rw', isa => ArrayRef[Int], default => sub{[]});
# A lookup array whose index is (sourceCardIndex | (destCardIndex << 4)) and whose output is the resulting index for the source cell.
has SOURCE_SHIFT_RESULTS => (is => 'rw', isa => ArrayRef[Int], default => sub{[]});

# Look up the card index by its face value.
has CARD_VALUE_TO_INDEX => ( is => 'rw', isa => HashRef[Int], default => sub{{}});

# Static constructor to initialize lookup arrays.
sub Initialize {
  my $self = shift;
  my $dest = $self->DEST_SHIFT_RESULTS;
  my $src = $self->SOURCE_SHIFT_RESULTS;
  my ($outputSourceIndex, $outputDestIndex);
  for my $sourceIndex ( 0 .. (scalar CARD_INDEX_TO_VALUE)-1) {
    for my $destIndex ( 0 .. (scalar CARD_INDEX_TO_VALUE)-1) {
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
        $outputDestIndex = $sourceIndex + 1; # Increasing the index one means doubling the face value.
      } else {
        $outputSourceIndex = $sourceIndex;
        $outputDestIndex = $destIndex;
      }

      my $lookupArrayIndex = $sourceIndex | ($destIndex << 4);
      $dest->[$lookupArrayIndex] = $outputDestIndex;
      $src->[$lookupArrayIndex] = $outputSourceIndex;
    }
  }
  my $i = 0;
  my $cvi = $self->CARD_VALUE_TO_INDEX;
  foreach (CARD_INDEX_TO_VALUE) {
    $cvi->{$_} = $i;
    $i++;
  }
}

# Returns the card index of the card at the specified x, y cooords.
# 0 means no card there.
sub GetCardIndex {
  my ($self, $x, $y) = @_;
  $x //= 0; $y //= 0;
  return vec($self->_board, $x + 4 * $y, 4);
}

# Returns the card index of the card at the specified cell.
# 0 means no card there.
sub GetCardIndexFromCell {
  my ($self, $cell) = @_;
  return $self->GetCardIndex($cell->X, $cell->Y);
}

# Sets the card index of the card at the specified cell.
# 0 means no card there.
sub SetCardIndex {
  my ($self, $x, $y, $cardIndex) = @_;
  my $board = $self->_board;
  vec($board, $x + 4 * $y, 4) = $cardIndex;
  $self->_board($board);
}

# Sets the card index of the card at the specified cell.
# 0 means no card there.
sub SetCardIndexFromCell {
  my ($self, $cell, $cardIndex) = @_;
  $self->SetCardIndex($cell->X, $cell->Y, $cardIndex);
}

# Returns the total point score of the current board.
sub GetTotalScore {
  my ($self) = @_;
  my $total = 0;
  for my $ix (0 .. ($self->Width * $self->Height)-1) {
    $total += (CARD_INDEX_TO_POINTS)[vec($self->_board,$ix,4)];
  }
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
      my $value = (CARD_INDEX_TO_VALUE)[$cardIndex];
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
  if    ($dir == 0)  {$self->ShiftLeft($newCardCells)}
  elsif ($dir == 1) {$self->ShiftRight($newCardCells)}
  elsif ($dir == 2)    {$self->ShiftUp($newCardCells)}
  elsif ($dir == 3)  {$self->ShiftDown($newCardCells)}
  else { die "Unknown ShiftDirection '$dir'.";}
  return $oldBoard ne $self->_board;
}

# Shifts this board in-place to the left.
sub ShiftLeft {
  my($self, $newCardCells) = @_;
  my $newBoard  = $self->_board;
  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard, 0, 4);
    $cellIndex[1] = vec($newBoard, 1, 4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard, 2, 4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard, 3, 4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[0] = Threesus::V2D->new(X => 3, Y => 0);
    } else {
      $newCardCells->[0] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard,0+4,4);
    $cellIndex[1] = vec($newBoard,1+4,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard,2+4,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard,3+4,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i+4, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[1] = Threesus::V2D->new(X => 3, Y => 1);
    } else {
      $newCardCells->[1] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard,0+8,4);
    $cellIndex[1] = vec($newBoard,1+8,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard,2+8,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard,3+8,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i+8, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[2] = Threesus::V2D->new(X => 3, Y => 2);
    } else {
      $newCardCells->[2] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard,0+12,4);
    $cellIndex[1] = vec($newBoard,1+12,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard,2+12,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard,3+12,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i+12, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[3] = Threesus::V2D->new(X => 3, Y => 3);
    } else {
      $newCardCells->[3] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }
  $self->_board($newBoard);
}

# Shifts this board in-place to the right.
sub ShiftRight {
  my($self, $newCardCells) = @_;
  my $newBoard  = $self->_board;
  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard,3,4);
    $cellIndex[1] = vec($newBoard,2,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard,1,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard,0,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[0] = Threesus::V2D->new(X => 0, Y => 0);
    } else {
      $newCardCells->[0] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard,3+4,4);
    $cellIndex[1] = vec($newBoard,2+4,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard,1+4,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard,0+4,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i+4, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[1] = Threesus::V2D->new(X => 0, Y => 1);
    } else {
      $newCardCells->[1] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard,3+8,4);
    $cellIndex[1] = vec($newBoard,2+8,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard,1+8,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard,0+8,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i+8, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[2] = Threesus::V2D->new(X => 0, Y => 2);
    } else {
      $newCardCells->[2] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard,3+12,4);
    $cellIndex[1] = vec($newBoard,2+12,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard,1+12,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard,0+12,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i+12, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[3] = Threesus::V2D->new(X => 0, Y => 3);
    } else {
      $newCardCells->[3] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }
  $self->_board($newBoard);
}

# Shifts this board in-place up.
sub ShiftUp {
  my($self, $newCardCells) = @_;
  my $newBoard  = $self->_board;
  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard, 0, 4);
    $cellIndex[1] = vec($newBoard, 4, 4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard, 8, 4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard, 12, 4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i*4, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[0] = Threesus::V2D->new(X => 0, Y => 3);
    } else {
      $newCardCells->[0] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard, 1+0, 4);
    $cellIndex[1] = vec($newBoard, 1+4, 4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard, 1+8, 4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard, 1+12, 4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i*4+1, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[1] = Threesus::V2D->new(X => 1, Y => 3);
    } else {
      $newCardCells->[1] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard, 2+0, 4);
    $cellIndex[1] = vec($newBoard, 2+4, 4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard, 2+8, 4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard, 2+12, 4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i*4+2, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[2] = Threesus::V2D->new(X => 2, Y => 3);
    } else {
      $newCardCells->[2] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard, 3+0, 4);
    $cellIndex[1] = vec($newBoard, 3+4, 4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard, 3+8, 4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard, 3+12, 4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i*4+3, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[3] = Threesus::V2D->new(X => 3, Y => 3);
    } else {
      $newCardCells->[3] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }
  $self->_board($newBoard);
}

# Shifts this board in-place down.
sub ShiftDown {
  my($self, $newCardCells) = @_;
  my $newBoard  = $self->_board;
  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard,12,4);
    $cellIndex[1] = vec($newBoard,8,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard,4,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard,0,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i*4, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[0] = Threesus::V2D->new(X => 0, Y => 0);
    } else {
      $newCardCells->[0] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard,1+12,4);
    $cellIndex[1] = vec($newBoard,1+8,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard,1+4,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard,1+0,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i*4+1, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[1] = Threesus::V2D->new(X => 1, Y => 0);
    } else {
      $newCardCells->[1] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard,2+12,4);
    $cellIndex[1] = vec($newBoard,2+8,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard,2+4,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard,2+0,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i*4+2, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[2] = Threesus::V2D->new(X => 2, Y => 0);
    } else {
      $newCardCells->[2] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $newBoard;

    my @cellIndex = ();
    $cellIndex[0] = vec($newBoard,3+12,4);
    $cellIndex[1] = vec($newBoard,3+8,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($newBoard,3+4,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($newBoard,3+0,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($newBoard, $i*4+3, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $newBoard) {
      $newCardCells->[3] = Threesus::V2D->new(X => 3, Y => 0);
    } else {
      $newCardCells->[3] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }
  $self->_board($newBoard);
}

# Returns whether the specified cards can merge together.
# Assumes that neither card index is 0.
sub CanCardsMerge {
  my ($self, $sourceCardIndex, $destCardIndex) = @_;
  my $arrayLookup = $sourceCardIndex | ($destCardIndex << 4);
  return $self->DEST_SHIFT_RESULTS->[$arrayLookup] != $destCardIndex;
}

1;
# vi:ai:et:sw=2 ts=2

