Games::Threesus
===============
Threesus is an A.I. program that knows how to play [Threes](http://asherv.com/threes/)! The Github repo
is here: https://github.com/waltdestler/Threesus.

This repo is an attempt to re-code the C-Sharp code into Perl 5 code primarily for my own interest and
understanding. However I also want to see if/where I can optimise the code to get decent performance.

I don't expect the Perl code (initially) to run within an order of magnitude as fast as the C# code.

## Getting started ##

This code should run in any version of Perl >= 5.10 (i.e. any Perl version in the last ten years).

Download the repo (git clone or ZIP file), fire up a Threes! game on your iPhone or iPad, start the Assistant
by typing: perl assistant.pl and follow the instructions for the game.

### Future developments ###

1. Recode this program to run on a [Parallella](http:parallella.org) board to speed up the AI.
2. Add a Raspberry Pi with camera module to photograph the iPad screen and OCR the state of the board.
3. Add two digital motors to the RPi to swipe the iPad screen in the desired direction.

