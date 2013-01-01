package Odyssey::TTPlugin::FirstPara;

use strict;
use warnings;

use base qw{Template::Plugin::Filter};

sub filter {

	my ($test, $str) = @_;
	$str =~ /^\<p class=\"writeup\"\>(.*?)\<\/p\>/;

	return $1;
}

1;


