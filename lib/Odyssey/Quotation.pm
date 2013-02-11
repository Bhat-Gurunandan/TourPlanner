package Odyssey::Quotation;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Dancer qw{:syntax};
use Dancer::Plugin::Database;

use DateTime::Format::Strptime;
use Moose;
use Data::Dumper;

use Moose::Util::TypeConstraints;

=head1 NAME

Odyssey::Quotation - The great new Odyssey::Quotation!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Odyssey::Quotation;

    my $foo = Odyssey::Quotation->new();
    ...
=cut

# define a custom DateTime Subtype
subtype 'OdysseyDateTime'
	=> as 'DateTime'
	=> where { $_->isa('DateTime') };

coerce 'OdysseyDateTime',
    from 'Str',
    via {
		
		require DateTime::Format::Strptime;
		my $strpt = DateTime::Format::Strptime->new({
			pattern => '%Y-%m-%d %H:%M:%S.000',
			time_zone => 'Asia/Kolkata'
		});
		$strpt->parse_datetime($_);
    };

has id => (
	is => 'ro',
	isa => 'Int',
	lazy => 1,
	builder => '_create_quotation',
);

has leadname => (
	is => 'ro',
	isa => 'Str',
	required => 1,
	default => 'John Doe and Party',
);

has pax => (
	is => 'ro',
	isa => 'Int',
	required => 1,
	default => 2,
);

has hotelcategory => (
	is => 'ro',
	isa => 'Int',
	required => 1,
	default => 10,
);

has single => (
	is => 'ro',
	isa => 'Maybe[Int]',
	required => 1,
	default => 1,
);

has double => (
	is => 'ro',
	isa => 'Maybe[Int]',
	required => 1,
	default => 0,
);

has twin => (
	is => 'ro',
	isa => 'Maybe[Int]',
	required => 1,
	default => 0,
);

has arrdate => (
	is => 'ro',
	isa => 'OdysseyDateTime',
	required => 1,
	default => sub { return DateTime->now(); },
	coerce => 1,
);

has depdate => (
	is => 'ro',
	isa => 'OdysseyDateTime',
	required => 1,
	default => sub { return DateTime->now(); },
	coerce => 1,
);

has arrplace => (
	is => 'ro',
	isa => 'Int',
	required => 1,
	default => 103,
);

has startplace => (
	is => 'ro',
	isa => 'Int',
	required => 1,
	default => 2,
);

has depplace => (
	is => 'ro',
	isa => 'Int',
	required => 1,
	default => 103,
);

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

# Get the next id. Not transaction safe.
sub _get_nextID {
	
	my $table = shift;
	my $column = $table . '_id';
	my $qry = "select max($column) from $table";
	
	my $sth = database->prepare($qry);
	$sth->execute;
	my $row = $sth->fetchrow_arrayref;
	$sth->finish;
	
	return 1 + $row->[0];
}

# Create a new quotation
sub _create_quotation {
	
	my $self = shift;
	
	my $id = _get_nextID('quotations');
	my $qry = "insert into
		quotations (
			quotations_id,
			trial,
			paxname,
			numpax,
			hoteltypes_id,
			numsingles,
			numdoubles,
			numtwins,
			dateofarrival,
			dateofdeparture,
			startcities_id,
			endcities_id
		)
		values (
			?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
		)";
	my $sth = database->prepare($qry);
	
	print STDERR Dumper([
		$id,
		1,
		$self->leadname,
		$self->pax,
		$self->hotelcategory,
		$self->single,
		$self->double,
		$self->twin,
		$self->arrdate->strftime('%Y-%m-%d %H:%M:%S.000'),
		$self->depdate->strftime('%Y-%m-%d %H:%M:%S.000'),
		$self->startplace,
		$self->depplace
	]);
	
	$sth->execute(
		$id,
		1,
		$self->leadname,
		$self->pax,
		$self->hotelcategory,
		$self->single,
		$self->double,
		$self->twin,
		$self->arrdate->strftime('%Y-%m-%d %H:%M:%S.000'),
		$self->depdate->strftime('%Y-%m-%d %H:%M:%S.000'),
		$self->startplace,
		$self->depplace
	);	
	
	return $id;
}

# creates a record if only id is supplied
around BUILDARGS => sub {

	my $orig = shift;
	my $class = shift;
	my @data = ( @_ == 1 && ! ref $_[0] ) ? _create_from_db($_[0]) : @_;
		
	return $class->$orig(@data);
};
  
=head2 function2

=cut

sub _create_from_db {
	
	my $id = shift;
	my $qry = "select
			quotations_id 	id, 
			paxname 		leadname,
			numpax 			pax,
			hoteltypes_id 	hotelcategory,
			numsingles 		single,
			numdoubles 		double,
			numtwins 		twin,
			dateofarrival   arrdate,
			dateofdeparture depdate,
			startcities_id 	startplace,
			endcities_id 	depplace
		from
			quotations
		where
			quotations_id = ?";
			
	my $sth = database->prepare($qry);
	$sth->execute($id);
	my $rec = $sth->fetchrow_hashref('NAME_lc');
	$sth->finish;

	# convert to datetime
	my $strpt = DateTime::Format::Strptime->new({
		pattern => '%Y-%m-%d %H:%M:%S.000',
		time_zone => 'Asia/Kolkata'
	});

	$rec->{arrdate} = $strpt->parse_datetime($rec->{arrdate});
	$rec->{depdate} = $strpt->parse_datetime($rec->{depdate});
	
	return %$rec;
}

=head1 AUTHOR

Gurunandan R. Bhat, C<< <gbhat at pobox.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-odyssey-quotation at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Odyssey-Quotation>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Odyssey::Quotation


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Odyssey-Quotation>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Odyssey-Quotation>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Odyssey-Quotation>

=item * Search CPAN

L<http://search.cpan.org/dist/Odyssey-Quotation/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Gurunandan R. Bhat.

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

1; # End of Odyssey::Quotation
