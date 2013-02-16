package Odyssey::DBQuotation;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Dancer qw{:syntax};
use Dancer::Plugin::Database;

use Exporter qw{import};
our @EXPORT = qw{
	create_quotation
	build_quotation
	generate_itinerary
};


# Create a new quotation
sub create_quotation {
	
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
	my $status = session('status');
	my $config = $status->{config};
	
	$sth->execute(
		$id,
		1,
		$config->{leadname},
		$config->{pax},
		$config->{hotelcategory},
		$config->{single},
		$config->{double},
		$config->{twin},
		$config->{arrdate},
		$config->{depdate},
		$config->{startplace},
		$config->{depplace}
	);	
	
	# Inserting cities
	my $stops = $status->{stops} || [];
	foreach (@$stops) {
		
		my $quo_city = {
			qid => $id,
			datein => $_->{arrdate},
			tocities_id => $_->{dest}{cityid},
			nights => $_->{days},
		};
		my $qcid = _create_quotation_city($quo_city);
		
		# Insert travel bookings
		if (defined $_->{route}) {

			my $hops = $_->{route}{hops};
			foreach (@$hops) {
				
				my $quo_tickets = {
					qid => $id,
					qcid => $qcid,
					traveldate => $_->{departure},
					from_cities_id => $_->{fromcities_id},
					to_cities_id => $_->{tocities_id},
					tickets_id => $_->{mode},
					flightno => $_->{modeno},
					trainno => $_->{trainno},
					overnight => $_->{overnight},
					hops => $_->{hops},
					modepreference => $_->{modepreference},
				};

				_create_quotation_tickets($quo_tickets);
			}
		}
		
		# Insert hotel bookings
		if (defined $_->{hotelid}) {

			my $quo_accomodation = {
				qid => $id,
				qcid => $qcid,
				datein => $_->{arrdate},
				hoteladdressbook_id => $_->{hotelid},
				nights => $_->{days},
			};
			
			_create_quotation_accommodation($quo_accomodation);		
		}
	}
	
	return $id;
}

# Insert into QuoCities
sub _create_quotation_city {
	
	my $data = shift;
	my $id = _get_nextID('quocities');
	
	my $qry = "insert into
		quocities (
			quocities_id,
			quotations_id,
			datein,
			tocities_id,
			nights
		)
		values (
			?, ?, ?, ?, ?
		)";
	my $sth = database->prepare($qry);
	$sth->execute(
		$id,
		$data->{qid},
		$data->{datein},
		$data->{tocities_id},
		$data->{nights}
	);
	
	return $id;
}

# Inserts into QuoTickets
sub _create_quotation_tickets {

	my $data = shift;
	my $id = _get_nextID('quotickets');
	
	my $qry = "insert into 
		quotickets (
			quotickets_id,
			quotations_id,
			quocities_id,
			traveldate,
			from_cities_id,
			to_cities_id,
			tickets_id,
			flightno,
			trainno,
			overnight,
			hops,
			modepreference
		)
		values (
			?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
		)";
	my $sth = database->prepare($qry);
	$sth->execute(
		$id,
		$data->{qid},
		$data->{qcid},
		$data->{traveldate},
		$data->{from_cities_id},
		$data->{to_cities_id},
		$data->{tickets_id},
		$data->{flightno},
		$data->{trainno},
		$data->{overnight},
		$data->{hops},
		$data->{modepreference}
	);
	
	return $id;
}

# Insert into Quo_Accommodation
sub _create_quotation_accommodation {
	
	my $data = shift;
	my $id = _get_nextID('quoaccommodation');
	
	my $qry = "insert into
		quoaccommodation (
			quoaccommodation_id,
			quotations_id,
			quocities_id,
			datein,
			hoteladdressbook_id,
			nights
		)
		values (
			?, ?, ?, ?, ?, ?
		);";
	my $sth = database->prepare($qry);
	$sth->execute(
		$id,
		$data->{qid},
		$data->{qcid},
		$data->{datein},
		$data->{hoteladdressbook_id},
		$data->{nights}
	);
	
	return $id;
}

sub build_quotation {
	
	my $qid = shift;

	my $qry = "exec p_AutoCompleteData $qid";
	my $sth_ac = database->prepare($qry);
	$sth_ac->execute;
	$sth_ac->finish;
	
	# debug to_dumper( $sth_ac->fetchall_arrayref({}) );
	
	$qry = "exec p_AutoExecuteAll $qid";
	my $sth_ae = database->prepare($qry);
	$sth_ae->execute;
	$sth_ae->finish;
	
	# debug to_dumper( $sth_ae->fetchall_arrayref({}) );
		
}

sub generate_itinerary {
	
	my $qid = shift;
	
	my $qry = "exec p_Rpt_DetailedItinerary2 $qid, 2";
	my $sth_ac = database->prepare($qry);
	$sth_ac->execute;
	
	return $sth_ac->fetchall_arrayref( {} );
}

# Generate next id for a table
# Assumes primary key column name 
# is "tablename_id" 
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



1;
