package Odyssey::RouteFinder;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Dancer qw{:syntax};
use Dancer::Plugin::Database;

use Date::Manip::Date;
use DateTime::Format::Strptime;

use Exporter qw{import};
our @EXPORT = qw{
	routefinder
	departuredate
	departuretime
	add_days_to_date
	compare_dates
};

=head1 NAME

Odyssey::RouteFinder - The great new Odyssey::RouteFinder!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Odyssey::RouteFinder;

    my $foo = Odyssey::RouteFinder->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 routefinder

=cut

sub routefinder {
	
	my ($from, $to, $tstmp) = @_;
	
	$tstmp = database->quote($tstmp);
	my $qry = "exec p_RouteFinder_x $tstmp, $from, $to, 3, 1, null";
	
	my $rtsth = database->prepare($qry);
	$rtsth->execute;
	
	my @opts;
	my @hops;
	my $previdx = 1;
	while (my $row = $rtsth->fetchrow_hashref('NAME_lc')) {
		
		my $idx = $row->{optionno};
		if ($idx != $previdx) {

			my @tmp = @hops;

			push @opts, {
				modestr => join(', ', map {$_->{modestr}} @tmp),
				hops => \@tmp,
				duration => duration($tmp[0]->{departure}, $tmp[-1]->{arrival}),
			};
			
			@hops = ();
		}
		
		push @hops, {
			optionno => $idx,
			modestr => $row->{modestr},
			fromcities_id => $row->{fromcities_id},
			fromcity => $row->{fromcity},
			tocities_id => $row->{tocities_id},
			tocity => $row->{tocity},
			mode => $row->{mode},
			modeno => $row->{modeno},
			trainno => $row->{trainno},
			departure => $row->{departure},
			arrival => $row->{arrival},
		};

		$previdx = $idx
	}
	push @opts, {
		modestr => join(', ', map {$_->{modestr}} @hops),
		hops => \@hops,
		duration => duration($hops[0]->{departure}, $hops[-1]->{arrival}),
	};
	
	return \@opts;	
}

=head2 departuredate

=cut

sub departuredate {
	
	my ($start, $end, $days) = @_;

	my $strpt = DateTime::Format::Strptime->new({
		pattern => '%Y-%m-%d %H:%M:%S.000',
		time_zone => 'Asia/Kolkata'
	});

	my $dtstart = $strpt->parse_datetime($start);

	my $dtend = $strpt->parse_datetime($end);
	$dtend = DateTime->new(
		year => $dtend->year,
		month => $dtend->month,
		day => $dtend->day,
		hour => 0,
		minute => 0,
		second => 0
	);

	my $du = DateTime::Duration->new(days => $days);
	$dtend->add_duration($du);
	my $depdate = $dtend->strftime('%Y-%m-%d %H:%M:%S.000');
	
	my $delta = $dtend - $dtstart;
	my $daynum = $delta->in_units('days');
	
	return ($daynum + 1, $depdate);
} 

sub departuretime {

	my $start = shift;
		
	my $strpt = DateTime::Format::Strptime->new({
		pattern => '%Y-%m-%d %H:%M:%S.000',
		time_zone => 'Asia/Kolkata'
	});
	my $dtstart = $strpt->parse_datetime($start);
	
	my $du = DateTime::Duration->new(hours => 9);
	$dtstart->add_duration($du);
	
	return $dtstart->strftime('%Y-%m-%d %H:%M:%S.000');
}

=head2 duration

=cut

sub duration {
	
	my ($start, $end) = @_;
	my $strpt = DateTime::Format::Strptime->new({
		pattern => '%Y-%m-%d %H:%M:%S.000',
		time_zone => 'Asia/Kolkata'
	});

	$start = $strpt->parse_datetime($start);
	$end = $strpt->parse_datetime($end);
	
	my $dt = $end->strftime('%s') - $start->strftime('%s');
	my $hours = int($dt/3600); 
	my $mins = int(($dt - 3600 * $hours) / 60); 

	$hours = ($mins > 30) ? $hours + 1 : $hours;
	return "$hours hours";
}


sub add_days_to_date {
	
	my ($start, $days) = @_;
	
	debug "Received strt time: $start";
	
	my $strpt = DateTime::Format::Strptime->new({
		pattern => '%Y-%m-%d %H:%M:%S.000',
		time_zone => 'Asia/Kolkata'
	});

	my $dtstart = $strpt->parse_datetime($start);
	my $du = DateTime::Duration->new(days => $days);
	$dtstart->add_duration($du);
	
	return $dtstart->strftime('%Y-%m-%d %H:%M:%S.000');
}

sub compare_dates {
	
	my ($from, $to) = @_;
	
	my $strpt = DateTime::Format::Strptime->new({
		pattern => '%Y-%m-%d %H:%M:%S.000',
		time_zone => 'Asia/Kolkata'
	});

	return DateTime->compare(
		$strpt->parse_datetime($from)->truncate(to => 'day'),
		$strpt->parse_datetime($to)->truncate(to => 'day')
	);
}

=head1 AUTHOR

Gurunandan R. Bhat, C<< <gbhat at pobox.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-odyssey at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Odyssey>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Odyssey::RouteFinder


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Odyssey>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Odyssey>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Odyssey>

=item * Search CPAN

L<http://search.cpan.org/dist/Odyssey/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Gurunandan R. Bhat.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Odyssey::RouteFinder
