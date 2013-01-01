#!perl

use strict;
use warnings;

use lib qw{../lib};

use Test::More;
use Odyssey::MemcacheDB;

is_deeply city(1), ['Abu Road', 26.647777778, 74.032500000], 'City gives correct result when lat/lng is non-null';
is_deeply city(51), ['Bijaynagar', undef, undef], 'City gives correct result when lat/lng is null';
