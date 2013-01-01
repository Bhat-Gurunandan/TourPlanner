$(document).ready(function(){
	
	// Get current city, lat, long
	var helem = $('h2#places'),
		here = helem.attr('city'),
		hereLat = helem.attr('lat'),
		hereLng = helem.attr('lng');
	
	
	var places = [];
	$('div.place').each(function(){
		
		var elem = $(this),
			lat = elem.attr('lat'),
			lng = elem.attr('lng'),
			cityid = elem.attr('cityid'),
			city = elem.attr('city'),
			oneliner = elem.find('h4').html(),
			desc = elem.find('p.desc').html();
		
		places.push({
			cityid: cityid,
			city: city,
			lat: lat,
			lng: lng,
			oneliner: oneliner,
			desc: desc
		});
	});
	
	var herePos = new google.maps.LatLng(hereLat, hereLng);
	var mapOpts = {
		zoom: 8,
		center: herePos,
		mapTypeId: google.maps.MapTypeId.ROADMAP
	};
	var map = new google.maps.Map($('#gmap').get(0), mapOpts);
	
	var hereMrkr = new google.maps.Marker({
		map: map,
		position: herePos,
		title: here,
		icon: '/images/blue-dot.png'
	});
	
	var mapBounds = new google.maps.LatLngBounds();
	mapBounds.extend(herePos);

	var infoWndw = new google.maps.InfoWindow({
		maxWidth: 250
	});
	
	for(i = 0; i < places.length; ++i) {
		
		var mLtLn = new google.maps.LatLng(places[i].lat, places[i].lng);
		var mOpts = {
			map: map,
			position: mLtLn,
			title: places[i].city,
			oID: i
		};
		var mMrkr = new google.maps.Marker(mOpts);
		mapBounds.extend(mLtLn);
		
		mrkrClickHandler(mMrkr);
	}
	
	map.fitBounds(mapBounds);
	
	function mrkrClickHandler(mrkr) {
		
		var idx = mrkr.oID;
		var place = places[idx];
		
		var city = place.city;
		var desc = place.desc;
		var cityid = place.cityid;
		
		var content = '<h5>'
			+ '<a href="/explore/' + city + '">'
			+ city
			+ '</a></h5><p>'
			+ desc
			+ '</p><p>'
			+ '<a href="/explore/' + city + '">Explore ' + city + '</a>'
			+ '</p>';
		
		google.maps.event.addListener(mrkr, 'click', function(){
			infoWndw.setContent(content);
			infoWndw.open(map, mrkr);
		});
	}
});
