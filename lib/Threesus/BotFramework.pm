# Creates a new BotFramework that evaluates moves using the specified logic evaluator.
package Threesus::BotFramework;
use v5.14;
use Moo;
use Types::Standard qw(Str Int ArrayRef);
use namespace::clean;
use enum qw(One Two Three Bonus);

# The number of moves into the future to examine. Should be at least 1.
has moveSearchDepth => ( is => 'ro', default => 6);
# The number of moves into the future in which the deck should be "card counted"
has cardCountDepth => ( is => 'ro', default => 3);


# Returns the next move to make based on the state of the specified game, or null to make no move.
sub GetNextMove {
  my ($self, $board, $deck, $nextCardHint, $movesEvaluated) = @_;
  $movesEvaluated //= 0;
  my $knownNextCardIndex;
  if    ($nextCardHint == One)   { $knownNextCardIndex = 1 }
  elsif ($nextCardHint == Two)   { $knownNextCardIndex = 2 }
  elsif ($nextCardHint == Three) { $knownNextCardIndex = 3 }
  elsif ($nextCardHint == Bonus) { $knownNextCardIndex = "Bonus" }
  else {die "Unknown NextCardHint '$nextCardHint'."}
  my $quality;
  return $self->GetBestMoveForBoard($board, $deck, $knownNextCardIndex, $self->moveSearchDepth - 1, \$quality, \$movesEvaluated);
}

# Returns the string representation of this Framework.
sub ToString {
  my ($self) = @_;
  return sprintf("Bot Framework\nMove Search Depth: %d\nCard Count Depth: %d\nEvaluator: %s",
    $self->moveSearchDepth,
    $self->cardCountDepth,
    "OpennessMathew");
}

# Returns the best move to make for the specified board, or null if there are no moves to make.
# Outputs the quality of the returned move.
sub GetBestMoveForBoard {
  my ($self, $board, $deck, $knownNextCardIndex, $recursionsLeft, $pmoveQuality, $pmovesEvaluated) = @_;
  my ($moves1, $moves2) = (0, 0);
  my $leftQuality = $self->EvaluateMoveForBoard($board, $deck, $knownNextCardIndex, 0, $recursionsLeft, \$moves1);
  my $rightQuality = $self->EvaluateMoveForBoard($board, $deck, $knownNextCardIndex, 1, $recursionsLeft, \$moves1);
  my $upQuality = $self->EvaluateMoveForBoard($board, $deck, $knownNextCardIndex, 2, $recursionsLeft, \$moves2);
  my $downQuality = $self->EvaluateMoveForBoard($board, $deck, $knownNextCardIndex, 3, $recursionsLeft, \$moves2);
  $$pmovesEvaluated += $moves1 + $moves2;

  my $bestQuality = $leftQuality;
  my $bestDir = $bestQuality ? "Left" : '';
  if($rightQuality > $bestQuality) {
    $bestQuality = $rightQuality;
    $bestDir = "Right";
  }
  if($upQuality > $bestQuality) {
    $bestQuality = $upQuality;
    $bestDir = "Up";
  }
  if($downQuality > $bestQuality) {
    $bestQuality = $downQuality;
    $bestDir = "Down";
  }
  $$pmoveQuality = $bestQuality;
  return $bestDir;
}

# Returns the quality value for shifting the specified board in the specified direction.
# Returns null if shifting in that direction is not possible.
sub EvaluateMoveForBoard {
  my ($self, $board, $deck, $knownNextCardIndex, $dir, $recursionsLeft, $pmovesEvaluated) = @_;
  my $shiftedBoard = $board;
  my $totalQuality;
  my $totalWeight;
  my $newCardCells = [];
  if( $shiftedBoard->ShiftInPlace($dir, $newCardCells)) {
    $totalQuality = 0;
    $totalWeight = 0;

    if( $knownNextCardIndex eq 'Bonus') {
      my $indexes = Game->new->GetPossibleBonusCardIndexes($board->GetMaxCardIndex);
      for my $i ( 0 .. $#{$indexes}) {
        my $cardIndex = $indexes->[$i];
        for my $cell (@{$newCardCells}) {
          next if ($cell->X < 0);

          my $newBoard = $shiftedBoard;
          $newBoard->SetCardIndexFromCell($cell, $cardIndex);

          my $quality;
          if ($recursionsLeft == 0
            or $self->GetBestMoveForBoard($newBoard, $deck, 0, $recursionsLeft-1, \$quality, $pmovesEvaluated) == 0) {
            $quality = $self->evaluator($newBoard);
            $$pmovesEvaluated++;
          }

          $totalQuality += $quality;
          $totalWeight += 1;
        }
      }
    } elsif ($knownNextCardIndex > 0) {
      my $newDeck = $deck;
      $newDeck->Remove($knownNextCardIndex);
      for my $cell (@{$newCardCells}) {
        next if ($cell->X < 0);

        my $newBoard = $shiftedBoard;
        $newBoard->SetCardIndexFromCell($cell, $knownNextCardIndex);

        my $quality;
        if ($recursionsLeft == 0
          or $self->GetBestMoveForBoard($newBoard, $newDeck, 0, $recursionsLeft-1, \$quality, $pmovesEvaluated) == 0) {
          $quality = $self->evaluator($newBoard);
          $$pmovesEvaluated++;
        }

        $totalQuality += $quality;
        $totalWeight += 1;
      }
    } elsif ($self->moveSearchDepth - $recursionsLeft - 1 < $self->cardCountDepth) {
      if ($deck->Ones > 0) {
        my $newDeck = $deck;
        $newDeck->RemoveOne;
        for my $cell (@{$newCardCells}) {
          next if ($cell->X < 0);

          my $newBoard = $shiftedBoard;
          $newBoard->SetCardIndexFromCell($cell, 1);

          my $quality;
          if ($recursionsLeft == 0
            or $self->GetBestMoveForBoard($newBoard, $newDeck, 0, $recursionsLeft - 1, \$quality, $pmovesEvaluated) == 0) {
            $quality = $self->evaluator($newBoard);
            $$pmovesEvaluated++;
          }

          $totalQuality += $quality * $deck->Ones;
          $totalWeight += $deck->Ones;
        }
      }

      if ($deck->Twos > 0) {
        my $newDeck = $deck;
        $newDeck->RemoveTwo;
        for my $cell (@{$newCardCells}) {
          next if ($cell->X < 0);

          my $newBoard = $shiftedBoard;
          $newBoard->SetCardIndexFromCell($cell, 2);

          my $quality;
          if ($recursionsLeft == 0
            or $self->GetBestMoveForBoard($newBoard, $newDeck, 0, $recursionsLeft - 1, \$quality, $pmovesEvaluated) == 0) {
            $quality = $self->evaluator($newBoard);
            $$pmovesEvaluated++;
          }

          $totalQuality += $quality * $deck->Twos;
          $totalWeight += $deck->Twos;
        }
      }
      if ($deck->Threes > 0) {
        my $newDeck = $deck;
        $newDeck->RemoveThree;
        for my $cell (@{$newCardCells}) {
          next if ($cell->X < 0);

          my $newBoard = $shiftedBoard;
          $newBoard->SetCardIndexFromCell($cell, 3);

          my $quality;
          if ($recursionsLeft == 0
            or $self->GetBestMoveForBoard($newBoard, $newDeck, 0, $recursionsLeft - 1, \$quality, $pmovesEvaluated) == 0) {
            $quality = $self->evaluator($newBoard);
            $$pmovesEvaluated++;
          }

          $totalQuality += $quality * $deck->Threes;
          $totalWeight += $deck->Threes;
        }
      }
      # Note that we're not taking the chance of getting a bonus card into consideration. That would be way too expensive at not much benefit.
    } else {
      my $quality;
      if ($recursionsLeft == 0
        or $self->GetBestMoveForBoard($shiftedBoard, $deck, 0, $recursionsLeft - 1, \$quality, $pmovesEvaluated) == 0) {
        $quality = $self->evaluator($shiftedBoard);
        $$pmovesEvaluated++;
      }
      $totalQuality += $quality;
      $totalWeight += 1;
    }
    return $totalQuality/$totalWeight;
  } else {
    return 0.0;
  }
}

# A BoardQualityEvaluator that calculates how "open" the board is.
# Evaluates the quality of a board into a single value.
sub evaluator {
  my ($self, $board) = @_;
  my $maxIndex = $board->GetMaxCardIndex;

  my $total = 0;
  for my $x (0 .. $board->Width-1) {
    for my $y (0 .. $board->Height-1) {
      my $cardIndex = $board->GetCardIndex($x, $y);
      if ($cardIndex == 0) {
        # 2 points for an empty cell.
        $total += 3;
      } else {
        my $leftCardIndex = $x > 0 ? $board->GetCardIndex($x - 1, $y) : 0;
        my $rightCardIndex = $x < $board->Width-1 ? $board->GetCardIndex($x + 1, $y) : 0;
        my $upCardIndex = $y > 0 ? $board->GetCardIndex($x, $y - 1) : 0;
        my $downCardIndex = $y < $board->Height-1 ? $board->GetCardIndex($x, $y + 1) : 0;

        # for each adjacent card we can merge with.
        if ($leftCardIndex  != 0 && $board->CanCardsMerge($cardIndex, $leftCardIndex))  {$total += 2;}
        if ($rightCardIndex != 0 && $board->CanCardsMerge($cardIndex, $rightCardIndex)) {$total += 2;}
        if ($upCardIndex    != 0 && $board->CanCardsMerge($cardIndex, $upCardIndex))    {$total += 2;}
        if ($downCardIndex  != 0 && $board->CanCardsMerge($cardIndex, $downCardIndex))  {$total += 2;}

        # negative if we're trapped between higher-valued cards, either horizontally or vertically.
        if (($x == 0 || ($leftCardIndex >= 3 && $cardIndex < $leftCardIndex)) &&
           ($x == $board->Width-1 || ($rightCardIndex >= 3 && $cardIndex < $rightCardIndex))) {$total -= 5;}
        if (($y == 0 || ($upCardIndex >= 3 && $cardIndex < $upCardIndex)) &&
           ($y == $board->Height-1 || ($downCardIndex >= 3 && $cardIndex < $downCardIndex)))  {$total -= 5;}

        # point if next to at least one card twice our value.
        if ($cardIndex >= 3) {
          if (($leftCardIndex  != 0 && $leftCardIndex == $cardIndex + 1) ||
              ($rightCardIndex != 0 && $rightCardIndex == $cardIndex + 1) ||
              ($upCardIndex    != 0 && $upCardIndex == $cardIndex + 1) ||
              ($downCardIndex  != 0 && $downCardIndex == $cardIndex + 1)) {$total += 2;}
        }

        if ($maxIndex > 4) { 
          # for each wall we're touching if we're the biggest card
          if ($cardIndex == $maxIndex) {
            if ($x == 0 || $x == 3) {
              $total += 3;
            }

            if ($y == 0 || $y == 3) {
              $total += 3;
            }
          }

          # for sticking next to the biggest piece
          if ($cardIndex == $maxIndex - 1) {
            my ($testX, $testY);
            if ($self->NeighborsWith($board, $x, $y, $maxIndex, \$testX, \$testY)) {
              $total += 1;

              # and a bonus if we're also along a wall
              if ($x == 0 || $x == 3) {$total += 1;}

              if ($y == 0 || $y == 3) {$total += 1;}
            }
          }

          # if we're two below
          if ($cardIndex == $maxIndex - 2) {
            # and we're neighbors with a 1-below
            my ($testX, $testY);
            if ($self->NeighborsWith($board, $x, $y, $maxIndex-1, \$testX, \$testY)) {
              # who is also neighbors with the max
              if ($self->NeighborsWith($board, $testX, $testY, $maxIndex, \$testX, \$testY)) {
                $total += 1;
              }
            }
          }
        }
      }
    }
  }
  return $total;
}

# Is a coordinate neighbors with a specific index?
sub NeighborsWith {
  my ($self, $board, $x, $y, $index, $testX, $testY) = @_;
  $x //= 0; $y //= 0;
  my $leftCardIndex = $x > 0 ? $board->GetCardIndex($x - 1, $y) : 0;
  my $rightCardIndex = $x < $board->Width - 1 ? $board->GetCardIndex($x + 1, $y) : 0;
  my $upCardIndex = $y > 0 ? $board->GetCardIndex($x, $y - 1) : 0;
  my $downCardIndex = $y < $board->Height - 1 ? $board->GetCardIndex($x, $y + 1) : 0;

  if ($leftCardIndex == $index) {
    $testX = $x - 1;
    $testY = $y;
    return 1;
  }

  if ($rightCardIndex == $index) {
    $testX = $x + 1;
    $testY = $y;
    return 1;
  }

  if ($upCardIndex == $index) {
    $testX = $x;
    $testY = $y - 1;
    return 1;
  }

  if ($downCardIndex == $index) {
    $testX = $x;
    $testY = $y + 1;
    return 1;
  }

  $testX = -1;
  $testY = -1;

  return;
}

1;
# vi:ai:et:sw=2 ts=2
