# Creates a new BotFramework that evaluates moves using the specified logic evaluator.
package Games::Threesus::Core::Bots::BotFramework;
use Moo;
use strictures 1;
use namespace::clean;

# The number of moves into the future to examine. Should be at least 1.
has moveSearchDepth => ( is => 'ro', default => 6);
# The number of moves into the future in which the deck should be "card counted"
has cardCountDepth => ( is => 'ro', default => 3);

# Returns the next move to make based on the state of the specified game, or null to make no move.
sub GetNextMove {
  my ($self, $board, $deck, $nextCardHint, $movesEvaluated) = @_;
  $movesEvaluated //= 0;
  my $knownNextCardIndex;
  given($nextCardHint) {
    $knownNextCardIndex = 1 when $NextCardHint->One;
    $knownNextCardIndex = 2 when $NextCardHint->Two;
    $knownNextCardIndex = 3 when $NextCardHint->Three;
    $knownNextCardIndex = "Bonus" when $NextCardHint->Bonus;
    default die "Unknown NextCardHint '$nextCardHint'.";
  }
  my $quality;
  return GetBestMoveForBoard($board, $deck, $knownNextCardIndex, $self->moveSearchDepth - 1, \$quality, $movesEvaluated);
}

# Returns the string representation of this Framework.
sub ToString {
  my $self = shift;
  return sprintf("Bot Framework\nMove Search Depth: %d\nCard Count Depth: %d\nEvaluator: %s",
    $self->moveSearchDepth,
    $self->cardCountDepth,
    "OpennessMathew");
}

# Returns the best move to make for the specified board, or null if there are no moves to make.
# Outputs the quality of the returned move.
sub GetBestMoveForBoard {
  my ($self, $board, $deck, $knownNextCardIndex, $recursionsLeft, $moveQuality, $movesEvaluated) = @_;
  my ($moves1, $moves2);
  my $leftQuality = $self->EvaluateMoveForBoard($board, $deck, $knownNextCardIndex, $ShiftDirection.Left, $recursionsLeft, \$moves1);
  my $rightQuality = $self->EvaluateMoveForBoard($board, $deck, $knownNextCardIndex, $ShiftDirection.Right, $recursionsLeft, \$moves1);
  my $upQuality = $self->EvaluateMoveForBoard($board, $deck, $knownNextCardIndex, $ShiftDirection.Up, $recursionsLeft, \$moves2);
  my $downQuality = $self->EvaluateMoveForBoard($board, $deck, $knownNextCardIndex, $ShiftDirection.Down, $recursionsLeft, \$moves2);
  $movesEvaluated += $moves1 + $moves2;

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
  $moveQuality = $bestQuality;
  return $bestDir;
}

# Returns the quality value for shifting the specified board in the specified direction.
# Returns null if shifting in that direction is not possible.
sub EvaluateMoveForBoard {
  my ($self, $board, $deck, $knownNextCardIndex, $dir, $recursionsLeft, $movesEvaluated) = @_;
  my $shiftedBoard = $board;
  my $totalQuality;
  my $totalWeight;
  my $newCardCells = [];
  if( $shiftedBoard->ShiftInPlace($dir, $newCardCells)) {
    $totalQuality = 0;
    $totalWeight = 0;

    if( $knownNextCardIndex eq 'Bonus') {
      my $indexes = [];
      Game.GetPossibleBonusCardIndexes(board.GetMaxCardIndex(), ref indexes);
      for(int i = 0; i < indexes.Count; i++)
      {
        ulong cardIndex = indexes.Items[i];
        for(int j = 0; j < 4; j++)
        {
          IntVector2D cell = newCardCells[j];
          if(cell.X < 0)
            continue;

          FastBoard newBoard = shiftedBoard;
          newBoard.SetCardIndex(cell, cardIndex);

          float quality;
          if(recursionsLeft == 0 || GetBestMoveForBoard(newBoard, deck, 0, recursionsLeft - 1, out quality, ref movesEvaluated) == null)
          {
            quality = $self->evaluator(newBoard);
            movesEvaluated++;
          }

          totalQuality += quality;
          totalWeight += 1;
        }
      }
    }
    else if(knownNextCardIndex > 0)
    {
      FastDeck newDeck = deck;
      newDeck.Remove(knownNextCardIndex);
      for(int i = 0; i < 4; i++)
      {
        IntVector2D cell = newCardCells[i];
        if(cell.X < 0)
          continue;

        FastBoard newBoard = shiftedBoard;
        newBoard.SetCardIndex(cell, knownNextCardIndex);

        float quality;
        if(recursionsLeft == 0 || GetBestMoveForBoard(newBoard, newDeck, 0, recursionsLeft - 1, out quality, ref movesEvaluated) == null)
        {
          quality = $self->evaluator(newBoard);
          movesEvaluated++;
        }

        totalQuality += quality;
        totalWeight += 1;
      }
    }
    else if(_moveSearchDepth - recursionsLeft - 1 < _cardCountDepth)
    {
      if(deck.Ones > 0)
      {
        FastDeck newDeck = deck;
        newDeck.RemoveOne();
        for(int i = 0; i < 4; i++)
        {
          IntVector2D cell = newCardCells[i];
          if(cell.X < 0)
            continue;

          FastBoard newBoard = shiftedBoard;
          newBoard.SetCardIndex(cell, 1);

          float quality;
          if(recursionsLeft == 0 || GetBestMoveForBoard(newBoard, newDeck, 0, recursionsLeft - 1, out quality, ref movesEvaluated) == null)
          {
            quality = $self->evaluator(newBoard);
            movesEvaluated++;
          }

          totalQuality += quality * deck.Ones;
          totalWeight += deck.Ones;
        }
      }

      if(deck.Twos > 0)
      {
        FastDeck newDeck = deck;
        newDeck.RemoveTwo();
        for(int i = 0; i < 4; i++)
        {
          IntVector2D cell = newCardCells[i];
          if(cell.X < 0)
            continue;

          FastBoard newBoard = shiftedBoard;
          newBoard.SetCardIndex(cell, 2);

          float quality;
          if(recursionsLeft == 0 || GetBestMoveForBoard(newBoard, newDeck, 0, recursionsLeft - 1, out quality, ref movesEvaluated) == null)
          {
            quality = $self->evaluator(newBoard);
            movesEvaluated++;
          }

          totalQuality += quality * deck.Twos;
          totalWeight += deck.Twos;
        }
      }

      if(deck.Threes > 0)
      {
        FastDeck newDeck = deck;
        newDeck.RemoveThree();
        for(int i = 0; i < 4; i++)
        {
          IntVector2D cell = newCardCells[i];
          if(cell.X < 0)
            continue;

          FastBoard newBoard = shiftedBoard;
          newBoard.SetCardIndex(cell, 3);

          float quality;
          if(recursionsLeft == 0 || GetBestMoveForBoard(newBoard, newDeck, 0, recursionsLeft - 1, out quality, ref movesEvaluated) == null)
          {
            quality = $self->evaluator(newBoard);
            movesEvaluated++;
          }

          totalQuality += quality * deck.Threes;
          totalWeight += deck.Threes;
        }
      }

      # Note that we're not taking the chance of getting a bonus card into consideration. That would be way too expensive at not much benefit.
    } else {
      float quality;
      if(recursionsLeft == 0 || GetBestMoveForBoard(shiftedBoard, deck, 0, recursionsLeft - 1, out quality, ref movesEvaluated) == null)
      {
        quality = $self->evaluator(shiftedBoard);
        movesEvaluated++;
      }

      totalQuality += quality;
      totalWeight += 1;
    }

    return totalQuality / totalWeight;
  } else {
    return;
  }
}

# A BoardQualityEvaluator that calculates how "open" the board is.
# Evaluates the quality of a board into a single value.
sub evaluator {
  my board = shift;
  var maxIndex = board.GetMaxCardIndex();

  int total = 0;
  for(int x = 0; x < FastBoard.Width; x++)
  {
    for(int y = 0; y < FastBoard.Height; y++)
    {
      ulong cardIndex = board.GetCardIndex(x, y);
      if(cardIndex == 0)
      {
        // 2 points for an empty cell.
        total += 3;
      }
      else
      {
        ulong leftCardIndex = x > 0 ? board.GetCardIndex(x - 1, y) : 0;
        ulong rightCardIndex = x < FastBoard.Width - 1 ? board.GetCardIndex(x + 1, y) : 0;
        ulong upCardIndex = y > 0 ? board.GetCardIndex(x, y - 1) : 0;
        ulong downCardIndex = y < FastBoard.Height - 1 ? board.GetCardIndex(x, y + 1) : 0;

        // for each adjacent card we can merge with.
        if(leftCardIndex != 0 && FastBoard.CanCardsMerge(cardIndex, leftCardIndex))
          total += 2;
        if(rightCardIndex != 0 && FastBoard.CanCardsMerge(cardIndex, rightCardIndex))
          total += 2;
        if(upCardIndex != 0 && FastBoard.CanCardsMerge(cardIndex, upCardIndex))
          total += 2;
        if(downCardIndex != 0 && FastBoard.CanCardsMerge(cardIndex, downCardIndex))
          total += 2;

        // negative if we're trapped between higher-valued cards, either horizontally or vertically.
        if((x == 0 || (leftCardIndex >= 3 && cardIndex < leftCardIndex)) &&
           (x == FastBoard.Width - 1 || (rightCardIndex >= 3 && cardIndex < rightCardIndex)))
        {
          total -= 5;
        }
        if((y == 0 || (upCardIndex >= 3 && cardIndex < upCardIndex)) &&
           (y == FastBoard.Height - 1 || (downCardIndex >= 3 && cardIndex < downCardIndex)))
        {
          total -= 5;
        }

        // point if next to at least one card twice our value.
        if(cardIndex >= 3)
        {
          if((leftCardIndex != 0 && leftCardIndex == cardIndex + 1) ||
             (rightCardIndex != 0 && rightCardIndex == cardIndex + 1) ||
             (upCardIndex != 0 && upCardIndex == cardIndex + 1) ||
             (downCardIndex != 0 && downCardIndex == cardIndex + 1))
          {
            total += 2;
          }
        }

        if(maxIndex > 4)
        {

          // for each wall we're touching if we're the biggest card
          if(cardIndex == maxIndex)
          {
            if(x == 0 || x == 3)
            {
              total += 3;
            }

            if(y == 0 || y == 3)
            {
              total += 3;
            }
          }

          // for sticking next to the biggest piece
          if(cardIndex == maxIndex - 1)
          {
            int testX, testY;
            if(NeighborsWith(board, x, y, maxIndex, out testX, out testY))
            {
              total += 1;

              // and a bonus if we're also along a wall
              if(x == 0 || x == 3)
              {
                total += 1;
              }

              if(y == 0 || y == 3)
              {
                total += 1;
              }
            }
          }

          // if we're two below
          if(cardIndex == maxIndex - 2)
          {
            // and we're neighbors with a 1-below
            int testX, testY;
            if(NeighborsWith(board, x, y, maxIndex - 1, out testX, out testY))
            {
              // who is also neighbors with the max
              if(NeighborsWith(board, testX, testY, maxIndex, out testX, out testY))
              {
                total += 1;
              }
            }
          }
        }
      }
    }
  }
  return total;
}

# Is a coordinate neighbors with a specific index?
sub NeighborsWith {
my (board, x, y, index, testX, testY) = @_;
  ulong leftCardIndex = x > 0 ? board.GetCardIndex(x - 1, y) : 0;
  ulong rightCardIndex = x < FastBoard.Width - 1 ? board.GetCardIndex(x + 1, y) : 0;
  ulong upCardIndex = y > 0 ? board.GetCardIndex(x, y - 1) : 0;
  ulong downCardIndex = y < FastBoard.Height - 1 ? board.GetCardIndex(x, y + 1) : 0;

  if(leftCardIndex == index)
  {
    testX = x - 1;
    testY = y;
    return true;
  }

  if(rightCardIndex == index)
  {
    testX = x + 1;
    testY = y;
    return true;
  }

  if(upCardIndex == index)
  {
    testX = x;
    testY = y - 1;
    return true;
  }

  if(downCardIndex == index)
  {
    testX = x;
    testY = y + 1;
    return true;
  }

  testX = -1;
  testY = -1;

  return false;

}

1;
# vi:ai:et:sw=2 ts=2
