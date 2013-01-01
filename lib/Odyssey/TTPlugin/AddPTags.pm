package Odyssey::TTPlugin::AddPTags;

use strict;
use warnings;

use base qw{Template::Plugin::Filter};

sub filter {
	
	my ($self, $str) = @_;
	return '<p class="writeup"></p>' unless $str;

	my @lines = split m{
		(?:					# make capturing if saving terminators 
				\x0D \x0A	# CRLF         
			|   \x0A		# LF 
			|   \x0D		# CR 
			|   \x0C		# FF 
			|   \x{2028}	# Unicode LS 
			|   \x{2029}	# Unicode PS 
		)
	}x, $str;
					
	return '<p class="writeup">' . join('</p><p class="writeup">', @lines) . '</p>';
}

1;