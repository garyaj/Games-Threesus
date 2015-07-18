# Stores a snapshot of the state of the game board.
# This version is much faster than the normal Board class, but doesn't contain unique Card IDs.
package Threesus::Board;
use strict;
use warnings;

use Carp;
use Threesus::V2D;

use enum qw{None Left Right Up Down};

# Contains fast lookup arrays by card number.
# Looks up the face value of a card by its 4-bit index.
my @CARD_INDEX_TO_VALUE = qw(
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
my @CARD_INDEX_TO_POINTS = qw(
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

sub new {
  my $class = shift;
  my $self = {@_};
  bless $self, $class;
  $self->_initialize();
  return $self;
}

sub Width { return $_[0]->{Width} }
sub Height { return $_[0]->{Height} }

sub board {
  my $self = shift;
  if (@_) {
    $self->{board} = shift;
  }
  return $self->{board};
}

sub DEST_SHIFT_RESULTS { return $_[0]->{DEST_SHIFT_RESULTS} }
sub SOURCE_SHIFT_RESULTS { return $_[0]->{SOURCE_SHIFT_RESULTS} }
sub CARD_VALUE_TO_INDEX { return $_[0]->{CARD_VALUE_TO_INDEX} }

# Static constructor to initialize lookup arrays.
sub _initialize {
  my $self = shift;
	$self->board(pack("C8", 0)); # 8 bytes = 16 nibbles at 4 bits per nibble = 64 bits.
	$self->{DEST_SHIFT_RESULTS} = [];
	$self->{SOURCE_SHIFT_RESULTS} = [];
  my ($outputSourceIndex, $outputDestIndex);
  for my $sourceIndex ( 0 .. $#CARD_INDEX_TO_VALUE) {
    for my $destIndex ( 0 .. $#CARD_INDEX_TO_VALUE) {
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
      $self->{DEST_SHIFT_RESULTS}->[$lookupArrayIndex] = $outputDestIndex;
      $self->{SOURCE_SHIFT_RESULTS}->[$lookupArrayIndex] = $outputSourceIndex;
    }
  }
  my $i = 0;
  foreach (@CARD_INDEX_TO_VALUE) {
    $self->{CARD_VALUE_TO_INDEX}->{$_} = $i;
    $i++;
  }
}

# Creates a copy of an existing board without the lookup arrays 
sub CopyFrom {
  my ($self, $board) = @_;
  $self->{DEST_SHIFT_RESULTS} = $board->DEST_SHIFT_RESULTS;
  $self->{SOURCE_SHIFT_RESULTS} = $board->SOURCE_SHIFT_RESULTS;
  $self->{Width} = $board->Width;
  $self->{Height} = $board->Height;
  $self->board($board->board);
}

# Returns the card index of the card at the specified x, y cooords.
# 0 means no card there.
sub GetCardIndex {
  my ($self, $x, $y) = @_;
  $x //= 0; $y //= 0;
  return vec($self->board, $x + 4 * $y, 4);
}

# Returns the card index of the card at the specified x, y cooords.
# 0 means no card there.
sub GetCardIndexValue {
  my ($self, $x, $y) = @_;
  return $CARD_INDEX_TO_VALUE[$self->GetCardIndex($x, $y)];
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
  vec($self->{board}, $x + 4 * $y, 4) = $cardIndex;
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
    $total += $CARD_INDEX_TO_POINTS[vec($self->board,$ix,4)];
  }
  return $total;
}

# Gets the card index of the highest-valued card on the board.
sub GetMaxCardIndex {
  my $self = shift;
  my $max = 0;
  for my $ix (0 .. ($self->Width * $self->Height)-1) {
    my $value = vec($self->board,$ix,4);
    $max = $value > $max ? $value : $max;
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
      push @vals, $self->GetCardIndexValue($x, $y);
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
  my $oldBoard = $self->board;
  if    ($dir == Left)  {$self->ShiftLeft($newCardCells)}
  elsif ($dir == Right) {$self->ShiftRight($newCardCells)}
  elsif ($dir == Up)    {$self->ShiftUp($newCardCells)}
  elsif ($dir == Down)  {$self->ShiftDown($newCardCells)}
  else { croak "Unknown ShiftDirection '$dir'.";}
  return $oldBoard ne $self->board;
}

# Shifts this board in-place to the left.
sub ShiftLeft {
  my($self, $newCardCells) = @_;
  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board, 0, 4);
    $cellIndex[1] = vec($self->board, 1, 4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board, 2, 4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board, 3, 4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[0] = Threesus::V2D->new(X => 3, Y => 0);
    } else {
      $newCardCells->[0] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board,0+4,4);
    $cellIndex[1] = vec($self->board,1+4,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board,2+4,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board,3+4,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i+4, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[1] = Threesus::V2D->new(X => 3, Y => 1);
    } else {
      $newCardCells->[1] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board,0+8,4);
    $cellIndex[1] = vec($self->board,1+8,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board,2+8,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board,3+8,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i+8, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[2] = Threesus::V2D->new(X => 3, Y => 2);
    } else {
      $newCardCells->[2] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board,0+12,4);
    $cellIndex[1] = vec($self->board,1+12,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board,2+12,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board,3+12,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i+12, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[3] = Threesus::V2D->new(X => 3, Y => 3);
    } else {
      $newCardCells->[3] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }
}

# Shifts this board in-place to the right.
sub ShiftRight {
  my($self, $newCardCells) = @_;
  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board,3,4);
    $cellIndex[1] = vec($self->board,2,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board,1,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board,0,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[0] = Threesus::V2D->new(X => 0, Y => 0);
    } else {
      $newCardCells->[0] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board,3+4,4);
    $cellIndex[1] = vec($self->board,2+4,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board,1+4,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board,0+4,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i+4, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[1] = Threesus::V2D->new(X => 0, Y => 1);
    } else {
      $newCardCells->[1] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board,3+8,4);
    $cellIndex[1] = vec($self->board,2+8,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board,1+8,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board,0+8,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i+8, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[2] = Threesus::V2D->new(X => 0, Y => 2);
    } else {
      $newCardCells->[2] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board,3+12,4);
    $cellIndex[1] = vec($self->board,2+12,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board,1+12,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board,0+12,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i+12, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[3] = Threesus::V2D->new(X => 0, Y => 3);
    } else {
      $newCardCells->[3] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }
}

# Shifts this board in-place up.
sub ShiftUp {
  my($self, $newCardCells) = @_;
  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board, 0, 4);
    $cellIndex[1] = vec($self->board, 4, 4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board, 8, 4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board, 12, 4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i*4, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[0] = Threesus::V2D->new(X => 0, Y => 3);
    } else {
      $newCardCells->[0] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board, 1+0, 4);
    $cellIndex[1] = vec($self->board, 1+4, 4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board, 1+8, 4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board, 1+12, 4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i*4+1, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[1] = Threesus::V2D->new(X => 1, Y => 3);
    } else {
      $newCardCells->[1] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board, 2+0, 4);
    $cellIndex[1] = vec($self->board, 2+4, 4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board, 2+8, 4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board, 2+12, 4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i*4+2, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[2] = Threesus::V2D->new(X => 2, Y => 3);
    } else {
      $newCardCells->[2] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board, 3+0, 4);
    $cellIndex[1] = vec($self->board, 3+4, 4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board, 3+8, 4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board, 3+12, 4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i*4+3, 4) = $cellIndex[$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[3] = Threesus::V2D->new(X => 3, Y => 3);
    } else {
      $newCardCells->[3] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }
}

# Shifts this board in-place down.
sub ShiftDown {
  my($self, $newCardCells) = @_;
  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board,12,4);
    $cellIndex[1] = vec($self->board,8,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board,4,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board,0,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i*4, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[0] = Threesus::V2D->new(X => 0, Y => 0);
    } else {
      $newCardCells->[0] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board,1+12,4);
    $cellIndex[1] = vec($self->board,1+8,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board,1+4,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board,1+0,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i*4+1, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[1] = Threesus::V2D->new(X => 1, Y => 0);
    } else {
      $newCardCells->[1] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board,2+12,4);
    $cellIndex[1] = vec($self->board,2+8,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board,2+4,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board,2+0,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i*4+2, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[2] = Threesus::V2D->new(X => 2, Y => 0);
    } else {
      $newCardCells->[2] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }

  {
    my $prevBoard = $self->board;

    my @cellIndex = ();
    $cellIndex[0] = vec($self->board,3+12,4);
    $cellIndex[1] = vec($self->board,3+8,4);

    my $arrayLookup = $cellIndex[1] | ($cellIndex[0] << 4);
    $cellIndex[0] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[1] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[2] = vec($self->board,3+4,4);
    $arrayLookup = $cellIndex[2] | ($cellIndex[1] << 4);
    $cellIndex[1] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[2] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    $cellIndex[3] = vec($self->board,3+0,4);
    $arrayLookup = $cellIndex[3] | ($cellIndex[2] << 4);
    $cellIndex[2] = $self->DEST_SHIFT_RESULTS->[$arrayLookup];
    $cellIndex[3] = $self->SOURCE_SHIFT_RESULTS->[$arrayLookup];

    for my $i (0 .. 3) {
      vec($self->{board}, $i*4+3, 4) = $cellIndex[3-$i];
    }
    if ($prevBoard ne $self->board) {
      $newCardCells->[3] = Threesus::V2D->new(X => 3, Y => 0);
    } else {
      $newCardCells->[3] = Threesus::V2D->new(X => -1, Y => -1);
    }
  }
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

