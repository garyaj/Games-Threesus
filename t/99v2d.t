#
#===============================================================================
#
#         FILE: 99v2d.t
#
#  DESCRIPTION: Test V2D.pm class.
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Gary Ashton-Jones (GAJ), gary@ashton-jones.com.au
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 10/07/2015 16:41:28
#     REVISION: ---
#===============================================================================

use v5.14;
use lib './lib';

use Test::More tests => 5;                      # last test to print
require_ok( 'Games::Threesus::Core::V2D' );

my $v = new_ok('Games::Threesus::Core::V2D' =>[X => 1, Y => 2]);
ok($v->X == 1, 'Got X');
ok($v->Y == 2, 'Got Y');
$v->X(4);
ok($v->X == 4, 'Got new X');

# vi:ai:et:sw=2 ts=2

