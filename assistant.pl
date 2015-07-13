#!/usr/bin/env perl
## An assistant that runs a Threes AI for the purposes of assisting the player play the actual game of Threes.
use v5.14;
use lib './lib';
use Games::Threesus::Core::Bots::BotFramework;
use Games::Threesus::Core::CoreGame::Deck;
use Games::Threesus::Core::CoreGame::Board;
use Games::Threesus::Core::CoreGame::Game;
use Data::Dumper;
use enum qw(One Two Three Bonus);

my $_bot = Games::Threesus::Core::Bots::BotFramework->new;

# Main application entry point.
# Build the board and initialize the deck.
my $deck = Games::Threesus::Core::CoreGame::Deck->new;
my $board = Games::Threesus::Core::CoreGame::Board->new;
$board->Initialise; #Initialise fast lookup arrays
say("Let's initialize the board...");
say("The format for each line should be four characters, each a 1, 2, 3, or any other character to represent an empty space.");
for my $y (0 .. $board->Height-1) {
  printf("Enter row %d: ", $y);
  my $rowStr = chomp(<>);
  if(length($rowStr->Length) != $board->Width) {
    say("Invalid length of entered row.");
    $y--;
    continue;
  }

  for my $x (0 .. $board->Width-1) {
    my $card = GetCardFromChar(substr($rowStr,$x,1), 0);
    if ($card) {
      $board->[$x][$y] = $card;
      $deck->RemoveCard($card->Value);
    }
  }
}
say("Board and deck successfully initialized.");

my $boardsStack = [];
my $decksStack = [];

# Now let's play!
while(1) {
redo:

  # Print the current board status.
  say("--------------------");
  for (my $y = 0; $y < $board->Height; $y++) {
    for (my $x = 0; $x < $board->Width; $x++) {
      my $c = $board->[$x][$y];
      if ($c) {
        printf("%d,", $c->Value);
      } else {
        print(" ,");
      }
    }
    say;
  }
  say("--------------------");
  printf("Current total score: %d\n", $board->GetTotalScore);

  # Get the next card.
  print("What is the next card? ");
  my $nextCardStr;
  my $nextCard;
  do
  {
    $nextCardStr = <>;
    chomp $nextCardStr;
    if ($nextCardStr eq "undo") {
      my $board = pop @$boardsStack;
      my $deck = pop @$decksStack;
      goto redo;
    }
  } while (length($nextCardStr) != 1 || !($nextCard = GetCardFromChar($nextCardStr, 1)));
  my $nextCardHint = GetNextCardHint($nextCard);

  # Choose a move.
  print("Thinking...");
  my $aiDir = $_bot->GetNextMove(FastBoard->new(Board => $board), FastDeck->new(Deck => $deck), $nextCardHint);
  if ($aiDir) {
    printf("\nSWIPE %s.\n", $aiDir);
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
  $board->Shift($actualDir, $newCardCells);

  # Get the new card location.
  my $newCardIndex;
  if (@$newCardCells > 1) {
    say("Here are the locations where a new card might have been inserted:");
    for (my $y = 0; $y < $board->Height; $y++) {
      for (my $x = 0; $x < $board->Width; $x++) {
        my $index = $newCardCells->[$x][$y];
        if ($index >= 0) {
          print(chr(ord('a') + $index));
        } else {
          print('.');
        }
      }
      say;
    }
    print("Where was it actually inserted? ");
    do
    {
      my $indexStr = <>;
      chomp $indexStr;
      if(length($indexStr) == 1) {
        $newCardIndex = ord($indexStr) - ord('a');
      } else {
        $newCardIndex = -1;
      }
    } while($newCardIndex < 0 || $newCardIndex >= @$newCardCells);
  } else {
    $newCardIndex = 0;
  }

  # Get new card value.
  my $newCardValue;
  if ($nextCardHint == Bonus) {
    do {
      print("!!! What is the value of the new card? ");
    } unless ($newCardValue = GetNewCardValue());
  } else {
    $newCardValue = $nextCardHint + 1;
  }
  $deck->RemoveCard($newCardValue);
  $board->[$newCardCells->[$newCardIndex]] = Card->new((Value => $newCardValue, UniqeID => -1);

  push @$boardsStack, Board->new($board);
  push @$decksStack, Deck->new($deck);
}

say("FINAL SCORE IS %d.", $board->GetTotalScore);
exit;

# Gets the card that is indicated by the specified character.
sub GetCardFromChar {
  my ($c, $allowBonusCard) = @_;
    if ($c eq '1') {
      return Card->new(Value => 1, UniqeID => -1);
    } elsif ($c eq '2') {
      return Card->new(Value => 2, UniqeID => -2);
    } elsif ($c eq '3') {
      return Card->new(Value => 3, UniqeID => -1);
    } elsif ($c eq '+') {
      if ($allowBonusCard) {
        return Card->new(Value => -1, UniqeID => -1);
      } else {
        return;
      }
    } else {
      return;
    }
}

# Returns the NextCardHint given the specified next card.
sub GetNextCardHint {
  if ($_[0] == 1) { return One; }
  if ($_[0] == 2) { return Two; }
  if ($_[0] == 3) { return Three; }
  # else
  return Bonus;
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
  if (  $str == 6 ||
        $str == 12 ||
        $str == 24 ||
        $str == 48 ||
        $str == 96 ||
        $str == 192 ||
        $str == 384 ||
        $str == 768 ||
        $str == 1536 ||
        $str == 3072 ||
        $str == 6144 ) {
    return $str;
  } else {
    return 0;
  }
}
# vi:ai:et:sw=2 ts=2

