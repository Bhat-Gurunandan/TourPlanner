#!perl

use strict;
use warnings;

use Test::More;

ok 2, 'This should pass';
is 5 + 2, 7, 'This should pass too';
ok 0, 'And this should fail';

done_testing();
