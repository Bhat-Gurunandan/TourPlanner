package Odyssey::MemcacheDB;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Dancer qw{:syntax};
use Dancer::Plugin::Database;
use Dancer::Plugin::MemcachedFast;

use Exporter qw{import};
our @EXPORT = qw{
	city
	cityid
	startcities
	nearcities
	randomcities
	hotel
	cityhotels
	defaulthotel
	citydetails
};

=head1 NAME

Odyssey::MemcacheDB - The great new Odyssey::MemcacheDB!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Odyssey::MemcacheDB;

    my $foo = Odyssey::MemcacheDB->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 city

=cut

sub city {
	
	my $cityid = shift;
	
	my $key = "city:$cityid";
	return memcached_get_or_set($key, sub {

		my $qry = "select 
			city,
			latitude,
			longitude
		from cities where cities_id = ?";
			
		my $sth = database->prepare($qry);
		$sth->execute($cityid);
		
		my $row = $sth->fetchrow_arrayref;
		$sth->finish;
		
		return $row;
	});
}

=head2 cityid

=cut

sub cityid {
	
	my $city = shift;

	my $key = "cityid:$city";
	return memcached_get_or_set($key, sub {

		my $sth = database->prepare("select cities_id from cities where city = ?");
		$sth->execute($city);
		
		my $row = $sth->fetchrow_arrayref;
		$sth->finish;
		
		return $row ? $row->[0] : undef;
	});
}

=head2 citydetails

=cut

sub citydetails {
	
	my $cityid = shift;
	my $key = "citydetails:$cityid";
	
	return memcached_get_or_set($key, sub {

		my $cqry = "select
				cities_id,
				city,
				oneliner,
				writeup,
				webwriteup,
				defaultdays,
				latitude,
				longitude,
				descr,
				keywords
			from 
				cities
			where
				cities_id = ?";
		
		my $csth = database->prepare($cqry);
		$csth->execute($cityid);
		my $citydetails = $csth->fetchrow_hashref('NAME_lc');
		$csth->finish;

		return $citydetails;		
	});
}

=head2 startcities

=cut

sub startcities {
	
	return memcached_get_or_set('startcities', sub {
		
		my $qry = "select 
			cities_id, 
			city, 
			airport
		from 
			cities 
		where 
			nighthalt = 1 and
			display = 1 and
			city not like '*%'  
		order by 
			city";
			
		return database->selectall_arrayref($qry, {Slice => {}});	
	});
}

=head2 nearcities

=cut

sub nearcities {
	
	my $cityid = shift;
	my $key = "nearcities:$cityid";
		
	return memcached_get_or_set($key, sub {

		my $nrqry = "select
			cities.cities_id,
			cities.city,
			cities.oneliner,
			cities.writeup,
			cities.latitude,
			cities.longitude
		from
			cities,
			nearcities
		where
			cities.cities_id = nearcities.cities_id and
			cities.display = 1 and
			nearcities.maincities_id = ?";
		
		my $nrsth = database->prepare($nrqry);
		$nrsth->execute($cityid);
	
		my $nearcities = $nrsth->fetchall_arrayref({});
		$nrsth->finish;
		
		return $nearcities;
	});
}

=head2 randomcities

=cut

sub randomcities {

	my $key = "randomcities";
	my $rndcities = memcached_get_or_set($key, sub {

		my $rcqry = "select distinct
				cities.cities_id,
				cities.city
			from
				cities,
				defaulthotels
			where
				cities.nighthalt = 1 and
				cities.display = 1 and
				cities.countries_id = 200 and
				defaulthotels.cities_id = cities.cities_id
			order by
				2";
				
		my $rcsth = database->prepare($rcqry);
		$rcsth->execute;
	
		my $rndcities = $rcsth->fetchall_arrayref({});
		$rcsth->finish;
	
		return $rndcities;
	});
	
	$key = $key . ':' . join(':', @_);

	my $cityid = $_[0];
	my %seen = map { $_ => 1 } @_;
	foreach (@{nearcities($cityid)}) {
		$seen{$_->{cities_id}} = 1;
	}		
		
	return memcached_get_or_set($key, sub {
		
		my @rndcities = grep { ! exists $seen{$_->{cities_id}} } @$rndcities;
		
		return \@rndcities;
	});
}

=head2 hotel

=cut

sub hotel {
	
	my $hotelid = shift;

	my $key = "hotel:$hotelid";
	return memcached_get_or_set($key, sub {

		my $sth = database->prepare("select organisation from addressbook where addressbook_id = ?");
		$sth->execute($hotelid);
		
		my $row = $sth->fetchrow_arrayref;
		$sth->finish;
		
		return $row ? $row->[0] : undef;
	});
}


=head2 cityhotels

=cut

sub cityhotels {

	# given hotel preference, returns default 
	# hotel *and* all hotels in a city	

	my $cityid = shift;
	my $key = "cityhotels:$cityid";
	
	return memcached_get_or_set($key, sub {
		
		my $hqry = "select
				wh.hotel_id,
				wh.hotel,
				wh.description,
				wh.category,
				wh.categoryname,
				dh.addressbook_id isdefault
			from (select
					h.addressbook_id hotel_id,
					h.organisation hotel,
					h.description description,
					h.city city,
					h.cities_id,
					case a2.categories_id 
						when 23 then 10 
						when 22 then 20 
						when 8 then 30 
						when 35 then 40 
					end as category,
					case a2.categories_id 
						when 23 then 'Standard' 
						when 22 then 'Superior' 
						when 8 then 'Luxury' 
						when 35 then 'Top of Line' 
					end as categoryname
					from
						vw_hoteldetails h,
						addresscategories a1,
				    	addresscategories a2
					where
						a1.categories_id = 27 and
						a2.categories_id in (23, 22, 8, 35) and
						a1.addressbook_id = h.addressbook_id and
						a2.addressbook_id = h.addressbook_id and
						h.cities_id = ?
				) wh
			left join
				 vw_defaulthotels dh
			on
				wh.hotel_id = dh.addressbook_id
			order by category";
		
		my $hsth = database->prepare($hqry);
		$hsth->execute($cityid);
		
		my $hotels = $hsth->fetchall_arrayref({});
		$hsth->finish;

		return $hotels;
	});
}

=head2 defaulthotel

=cut

sub defaulthotel {
	
	my ($cityid, $hotelpref) = @_;
	my $key = "defaulthotel:$cityid:hotelpref";

	my $hotels = cityhotels($cityid);	
	return memcached_get_or_set($key, sub {

		# Find default hotel closest to hotelcategory preference
		my $defhotel = $hotels->[0];

		foreach (@{$hotels}) {

			next unless $_->{isdefault};
			last if ($_->{category} > $hotelpref);
			$defhotel = $_;
		}

		return $defhotel;
	});
}

=head1 AUTHOR

Gurunandan R. Bhat, C<< <gbhat at pobox.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-odyssey at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Odyssey>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Odyssey::MemcacheDB


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

1; # End of Odyssey::MemcacheDB
