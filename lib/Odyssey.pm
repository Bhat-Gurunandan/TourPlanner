package Odyssey;

use Dancer ':syntax';

use Data::FormValidator;
use Date::Manip::Date;
use Data::Dumper;

use DateTime::Format::Strptime;

use Odyssey::MemcacheDB;;
use Odyssey::RouteFinder;
use Odyssey::DBQuotation;

our $VERSION = '0.1';

get '/' => sub {
	
	return redirect(uri_for('/diy'));
};

get '/tview/:template' => sub {
	
	my $template = params->{template};
	template $template;
};

get '/diy' => sub {
	
	my $cities = startcities();
	my @airports = grep {$_->{airport}} @$cities;

	my $valid = {
		pax => 2,
		hotelcategory => 10,
		double => 1,
		arrplace => 103,
		depplace => 103,
		startplace => 103,
	};
	
	template diy => {
		cities => $cities, 
		airports => \@airports,
		valid => $valid,
	};
};

post '/diy' => sub {
	
	my $results = validate_diy({
		leadname		=> params->{leadname},
		pax				=> params->{pax},
		hotelcategory	=> params->{hotelcategory},
		arrdate			=> params->{arrdate},
		arrplace		=> params->{arrplace},
		startplace		=> params->{startplace},
		depdate			=> params->{depdate},
		depplace		=> params->{depplace},
		single			=> params->{single},
		double			=> params->{double},
		twin			=> params->{twin},
	});

	my $valid = $results->valid;
	if (! $results->success) {
		
		my $cities = startcities();
		my @airports = grep {$_->{airport}} @$cities;
		
		return template diy => {
			cities => $cities, 
			airports => \@airports, 
			err => $results->msgs,
			valid => $valid,
		};
	}
	
	# All timestamps in YYYY-MM-DD HH24:MM:SS.000 format
	# required so template toolkit can parse the date
	my $dmd = Date::Manip::Date->new;
	$dmd->parse($valid->{arrdate});
	my $atstmp = $dmd->printf('%Y-%m-%d 00:00:00.000');
	
	$dmd->new_date;
	$dmd->parse($valid->{depdate});
	my $dtstmp = $dmd->printf('%Y-%m-%d 00:00:00.000');
	my $tourlength = duration_days($atstmp, $dtstmp);
	
	my $valid_data = {
		leadname		=> $valid->{leadname},
		pax				=> $valid->{pax},
		hotelcategory	=> $valid->{hotelcategory},
		single			=> $valid->{single},
		double			=> $valid->{double},
		twin			=> $valid->{twin},
		arrdate			=> $atstmp,
		arrplace		=> $valid->{arrplace},
		startplace		=> $valid->{startplace},
		depdate			=> $dtstmp,
		depplace		=> $valid->{depplace},
		tourlength 		=> $tourlength,
	};
	
	my ($currcity, $lat, $lng) = @{city($valid->{arrplace})};
	my ($city) = @{city($valid->{startplace})};

	# Init session
	session status => {
		config => $valid_data,
		src => {
			cityid	=> $valid->{arrplace},
			city	=> $currcity,
			lat		=> $lat,
			lng		=> $lng,
			daynum	=> 1,
			date 	=> $atstmp,
			etd		=> $atstmp,
		},
		dest => {
			cityid	=> $valid->{startplace},
			city	=> $city,
			routes	=> []
		},
		stops => [],
	};
	
	return redirect uri_for('explore/' . $city);
};

post '/explore' => sub {
	
	# Just a redirector for random cities
	
	# Go to DIY Form if no session and non-existent city
	return redirect uri_for('diy') 
		unless ((my $status = session('status')) && (my $city = params->{rcity}));

	return redirect uri_for('/explore/' . $city );
};

get '/explore/:city' => sub {
	
	my $city = params->{city};

	# Go to DIY Form if no session and non-existent city
	return redirect uri_for('diy') 
		unless ((my $status = session('status')) && (my $destid = cityid($city)));

	# What follows - assumes that all is well
	my $from 	= $status->{src}{cityid};
	my $to		= $destid;
	my $hpref 	= $status->{config}{hotelcategory};
		
	my $routes = [];
	$routes = routefinder($from, $to, $status->{src}{etd})
		unless ($from == $to);
		 
	my $citydetails = {

		%{citydetails($to)},
		hotels 		=> cityhotels($to),
		defhotel 	=> defaulthotel($to, $hpref),
		nearcities 	=> nearcities($from),
		randomcities => randomcities($from, $to),
		routes 		=> $routes,
	};

	# Update destination and routes.
	session status => {
		%{session('status')},
		dest => {
			cityid => $destid,
			city => $city,
			routes => $routes,
		}
	};

	template move_to => {%$citydetails, daywiseitin => build_itinerary()};
};

post '/transit' => sub {
	
	# Go to DIY Form if no session and non-existent city
	my $status = session('status');
	
	return redirect uri_for('diy') 
		unless $status;

	my $params = params;
	my $days = $params->{days};
	my $trvlopts = $params->{travelopts};
	my $hotelid = $params->{hotelid};

	my $dest = $status->{dest};
	my $city = $dest->{city};
	
	my (undef, $lat, $lng) = @{city($dest->{cityid})};
	
	my ($route, $arrtime);
	if (defined $trvlopts) {
		
		$route = $dest->{routes}[$trvlopts];
		$arrtime = $route->{hops}[-1]{arrival};
	}
	else {
		
		$arrtime = $status->{src}{etd};
	}
	
	# Get arrival daynum at destination
	my ($arrdaynum, undef) = departuredate (
		$status->{config}{arrdate},
		$arrtime, 
		0
	);
	
	# Get departure daynum from source
	my ($daynum, $date) = departuredate (
		$status->{config}{arrdate},
		$arrtime, 
		$days
	);
	
	my $hotel = hotel($hotelid);
	
	push @{$status->{stops}}, {
		src => $status->{src},
		dest => {
			%$dest, 
			routes => {},
			daynum => $arrdaynum,
		},
		route => $route,
		hotelid => $hotelid,
		hotel => $hotel,
		arrdate => $arrtime,
		depdate => $date,
		days => $days,
	};
		
	session status => {
		%$status,
		src => {
			cityid		=> $status->{dest}{cityid},
			city		=> $status->{dest}{city},
			lat			=> $lat,
			lng			=> $lng,
			daynum		=> $daynum,
			date 		=> $date,
			etd			=> departuretime($date),
		},
		dest => {},
	};

	debug to_dumper(session('status')->{stops});
		
	return redirect(uri_for('/explore_around/' . $city));
};

get '/explore_around/:city' => sub {
	
	# Go to DIY Form if no session and non-existent city
	my $status = session('status');
	
	my $city = param 'city';
	return redirect uri_for('diy') 
		unless (
			$status &&
			(my $cityid = $status->{src}{cityid}) &&
			($city eq $status->{src}{city})
		);
		
	my $options = nearcities($cityid);
	

	my $itin = build_itinerary();

	template move_on => {
		cities => $options, 
		randomcities => randomcities($cityid),
		daywiseitin => build_itinerary(),
	};	
};

get '/stops' => sub {
	
	my $stops = session('status')->{stops};
	my @cities;
	
	foreach ( @{$stops} ) {
		
		push @cities, $_->{src};		
	}
	push @cities, session('status')->{src};
	
	return to_json(\@cities);
};

get '/end_tour' => sub {
	
	my $qid = create_quotation();

	# Save Quotation
	my $status = session('status');
	$status->{config}{quotationid} = $qid;
	session('status', $status);
	
	build_quotation($qid);
	my $rpt = generate_itinerary($qid);
	
	debug to_dumper($rpt);
	
	template end_tour => {
		report => $rpt,
		daywiseitin => build_itinerary(),
	};
};

post '/end_tour' => sub {
	
	template thank_you => {daywiseitin => build_itinerary()};
};

sub validate_diy {
	
	my $inp = shift;
	
	my $dfv = {
		filters => ['trim'],
		required => [qw{
			leadname
			pax
			hotelcategory
			arrdate
			arrplace
			startplace
			depdate
			depplace
		}],
		require_some => {
			bedroom_type => [
				1, 
				qw{
					single
					double
					twin
				}
			]
		},
		constraints => {
			arrdate => {
				name => 'valid_date',
				constraint => \&validate_date,
			},
			depdate => {
				name => 'valid_date',
				constraint => \&validate_date,
			},
			depdate => {
				name => 'depart_after_arrive',
				params => [qw{arrdate depdate}],
				constraint => sub {

					my ($arr, $dep) = @_;
					
					my $arrd = Date::Manip::Date->new;
					my $depd = Date::Manip::Date->new;

					$arrd->parse($arr);
					$depd->parse($dep);
					
					return ($arrd->cmp($depd) == 1) ? 0 : 1;
				}
			}
		},
		msgs => {
			missing => 'This field is required',
			invalid => 'This value is invalid',
			constraints => {
				depart_after_arrive => 'Departure Date cannot be before Arrival',
				bedroom_type => 'At least one room type must be chosen',
				require_some => 'At least one room type must be chosen',
			},
		},
		debug => 1,
	};
	
	return my $results = Data::FormValidator->check($inp, $dfv);
}

sub validate_date {
	
	my $d = pop;
	
	my $dd = new Date::Manip::Date;
	my $err = $dd->parse($d);	

	return ! $err;
}

sub build_accoquote {
	
	my $status = session('status');
	return undef unless
		$status && (my $stops = $status->{stops});
	
	my @quotes = ();
	foreach (@{$stops}) {
		
		push @quotes, {
			cityid => $_->{dest}{cityid},
			city => $_->{dest}{city},
			hotelid => $_->{hotelid},
			hotel => $_->{hotel},
			from => $_->{arrdate},
			to => $_->{depdate}, 
			days => $_->{days},
		};
	}

	return \@quotes;	
}

sub build_itinerary {
	
	my $status = session('status');
	
	return unless
		$status && (my $stops = $status->{stops});
	
	my @itin = ();
	my ($depdaynum, $depdate, $depcity, $days);
	my @stops = @{$stops};

	foreach (@stops) {
		
		my $src = $_->{src};
		my $dest = $_->{dest};

		$itin[$src->{daynum}]->{desc} = $itin[$src->{daynum}]->{desc} || '';
		
		my $depnotice = $src->{cityid} == $dest->{cityid} ? 
			undef: 
			'Depart ' . $src->{city} . ' for ' . $dest->{city} . '. ';
			
		$itin[$src->{daynum}] = {
			
			date => $src->{date},
			desc =>  $depnotice || $itin[$src->{daynum}]->{desc},
			cont => 'In Transit', 
		};
		
		$itin[$dest->{daynum}]->{desc} = $itin[$dest->{daynum}]->{desc} || '';
		$itin[$dest->{daynum}] = {

			date => $_->{arrdate}, 
			desc => $itin[$dest->{daynum}]->{desc} || $dest->{city} . '.',
			cont => $dest->{city},
		};
		
		$depdate = $_->{depdate};
		$depdaynum = $dest->{daynum};
		$depcity = $dest->{city};
		$days = $_->{days};
	}
	if (@stops) {
		$itin[$depdaynum + $days] = {
			date => $depdate,
			desc => 'Ready to depart ' . $depcity,
			cont => '',
		};
	}
	
	# The first element is junk
	if (@itin) {
		shift @itin;
	}
	else {
		return [];
	}
	
	my $enddate = $status->{config}{depdate};
	my ($date, $desc, $delayed);
	foreach (@itin) {
		
		
		if ($_) {
			
			$date = $_->{date};
			$desc = $_->{cont};
			$delayed = compare_dates($date, $enddate);
			$_->{delayed} = $delayed; 
		}
		else {
			
			$date = add_days_to_date($date, 1);
			$delayed = compare_dates($date, $enddate);
			$_ = {
				date => $date,
				desc => $desc,
				delayed => $delayed,
			};
		}
	}
	
	while ($delayed < 0) {
		
		$date = add_days_to_date($date, 1);
		$delayed = compare_dates($date, $enddate);

		push @itin, {
			date => $date,
			desc => ($delayed == 0) ? 'Departure Date' : 'Plan Pending',
			delayed => $delayed,
		}
	}

	return \@itin;	
}

true;
