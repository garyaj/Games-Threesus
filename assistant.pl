#!/usr/bin/env perl
## An assistant that runs a Threes AI for the purposes of assisting the player play the actual game of Threes.
use v5.14;
use lib './lib';
use Threesus::Board;
use Threesus::Card;
use Threesus::Deck;
use Threesus::Game;
use Threesus::FastDeck;
use Threesus::BotFramework;
use Data::Dumper;

my $_bot = Threesus::BotFramework->new;

# Main application entry point.
# Build the board and initialize the deck.
my $deck = Threesus::Deck->new;
$deck->RebuildDeck;
my $fd = Threesus::FastDeck->new;
$fd->Initialize;
my $board = Threesus::Board->new;
$board->Initialize;    #Initialise fast lookup arrays
say("Let's initialize the board...");
say(
"The format for each line should be four characters, each a 1, 2, 3, or any other character to represent an empty space."
);

for my $y ( 0 .. $board->Height - 1 ) {
  printf( "Enter row %d: ", $y );
  my $rowStr = <>;
  chomp $rowStr;
  if ( length($rowStr) != $board->Width ) {
    say("Invalid length of entered row.");
    $y--;
    continue;
  }

  for my $x ( 0 .. $board->Width - 1 ) {
    my $cardval = GetCardValFromChar( substr( $rowStr, $x, 1 ), 0 );
    if ( $cardval > 0 ) {
      my $bd = $board->_board;
      vec( $bd, $x + 4 * $y, 4 ) = $cardval;
      $board->_board($bd);
      $deck->RemoveCard($cardval);
    }
  }
}
say("Board and deck successfully initialized.");

my $boardsStack = [];
my $decksStack  = [];

# Now let's play!
while (1) {
redo:

  # Print the current board status.
  say("--------------------");
  for my $y ( 0 .. $board->Height - 1 ) {
    for my $x ( 0 .. $board->Width - 1 ) {
      my $c = $board->GetCardIndex( $x, $y );
      if ($c) {
        printf( "%d,", $c );
      } else {
        print(" ,");
      }
    }
    say;
  }
  say("--------------------");

  printf( "Current total score: %d\n", $board->GetTotalScore );

  # Get the next card.
  print("What is the next card? ");
  my $nextCardStr;
  my $nextCard;
  do {
    $nextCardStr = <>;
    chomp $nextCardStr;
    if ( $nextCardStr eq "undo" ) {
      my $board = pop @$boardsStack;
      my $deck  = pop @$decksStack;
      goto redo;
    }
    } while ( length($nextCardStr) != 1
    || !( $nextCard = GetCardValFromChar( $nextCardStr, 1 ) ) );
  my $nextCardHint = GetNextCardHint($nextCard);

  # Choose a move.
  print("Thinking...");
  my $aiDir = $_bot->GetNextMove( $board, $fd, $nextCardHint );
  if ($aiDir) {
    printf( "\nSWIPE %s.\n", $aiDir );
  } else {
    say("NO MORE MOVES.");
    break;
  }

  # Confirm the swipe.
  my $actualDir = $aiDir;

# /*do
# {
#   print("What direction did you swipe in? (l, r, u, d, or just hit enter for the suggested swipe) ");
#   string dirStr = Console.ReadLine();
#   actualDir = GetShiftDirection(dirStr, aiDir.Value);
# }
# while(actualDir == null);*/
  my $newCardCells = [];
  $board->ShiftInPlace( $actualDir, $newCardCells );

  # Get the new card location.
  my $newCardIndex;
  if ( @$newCardCells > 1 ) {
    say("Here are the locations where a new card might have been inserted:");
    for my $y ( 0 .. $board->Height - 1 ) {
      for my $x ( 0 .. $board->Width - 1 ) {
        my $index = $newCardCells->[$x][$y];
        if ( $index >= 0 ) {
          print( chr( ord('a') + $index ) );
        } else {
          print('.');
        }
      }
      say;
    }
    print("Where was it actually inserted? ");
    do {
      my $indexStr = <>;
      chomp $indexStr;
      if ( length($indexStr) == 1 ) {
        $newCardIndex = ord($indexStr) - ord('a');
      } else {
        $newCardIndex = -1;
      }
    } while ( $newCardIndex < 0 || $newCardIndex >= @$newCardCells );
  } else {
    $newCardIndex = 0;
  }

  # Get new card value.
  my $newCardValue;
  if ( $nextCardHint == 3 ) {
    do {
      print("!!! What is the value of the new card? ");
    } unless ( $newCardValue = GetNewCardValue() );
  } else {
    $newCardValue = $nextCardHint + 1;
  }
  $deck->RemoveCard($newCardValue);
  my $cell = $newCardCells->[$newCardIndex];
  vec( $board->_board, $cell->X + 4 * $cell->Y, 4 ) = $newCardValue;

  push @$boardsStack, $board;
  push @$decksStack,  $deck;
}

say( "FINAL SCORE IS %d.", $board->GetTotalScore );
exit;

# Gets the card that is indicated by the specified character.
sub GetCardValFromChar {
  my ( $c, $allowBonusCard ) = @_;
  if ( $c eq '1' ) {
    return 1;
  } elsif ( $c eq '2' ) {
    return 2;
  } elsif ( $c eq '3' ) {
    return 3;
  } elsif ( $c eq '+' ) {
    if ($allowBonusCard) {
      return -1;
    } else {
      return 0;
    }
  } else {
    return 0;
  }
}

# Returns the NextCardHint given the specified next card.
sub GetNextCardHint {
  if ( $_[0] == 1 ) { return 0; }    #One
  if ( $_[0] == 2 ) { return 1; }    #Two
  if ( $_[0] == 3 ) { return 2; }    #Three
                                     # else
  return 3;                          #Bonus
}

# Returns the shift direction as specified by the specified string, or null if none was specified.
# If the string has no length, then the defaultDir will be returned.
# sub GetShiftDirection {
#   my ($c, $defaultDir) = @_;
#   if (!$c) {
#     return $defaultDir;
#   } elsif (length($c) > 1) {
#     return '';
#   } else {
#     if ($c eq 'l') { return 'Left'; }
#     if ($c eq 'r') { return 'Right'; }
#     if ($c eq 'u') { return 'Up'; }
#     if ($c eq 'd') { return 'Down'; }
#     #else
#     return '';
#   }
# }

# Attempts to extract the value of a new card from the specified string.
sub GetNewCardValue {
  my $str = <>;
  chomp $str;
  $str += 0;

  # Verify that it's a real card.
  if ( $str == 6
    || $str == 12
    || $str == 24
    || $str == 48
    || $str == 96
    || $str == 192
    || $str == 384
    || $str == 768
    || $str == 1536
    || $str == 3072
    || $str == 6144 )
  {
    return $str;
  } else {
    return 0;
  }
}

# vi:ai:et:sw=2 ts=2

