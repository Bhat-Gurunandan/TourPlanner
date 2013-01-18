$(document).ready(function(){

	$.get('/stops', function(data){

		// TODO: Get center of country;
		var cLat = 20;
		var cLng = 77;
						
		var cPos = new google.maps.LatLng(cLat, cLng);
		var mapOpts = {
			zoom: 4,
			center: cPos,
			mapTypeId: google.maps.MapTypeId.ROADMAP
		};
		var map = new google.maps.Map($('#gmap').get(0), mapOpts);

		var mapBounds = new google.maps.LatLngBounds();
		var stops = data.length;

		console.log(stops);
		
		var lastCity = '';
		var stopNum = 1;		
		for(i = 0; i < stops; ++i) {
			
			console.log(data[i]);
			
			if (data[i].city == lastCity) continue;
			
			
			var mLtLn = new google.maps.LatLng(data[i].lat, data[i].lng);
			var mOpts = {
				map: map,
				position: mLtLn,
				title: 'Stop ' + stopNum + ' in ' + data[i].city,
				icon: '/images/mapmarkers/iconb' + stopNum + '.png'
			};
			
			var mMrkr = new google.maps.Marker(mOpts);
			mapBounds.extend(mLtLn);
			++stopNum;
			lastCity = data[i].city;
		}
	
		map.fitBounds(mapBounds);

		var listener = google.maps.event.addListener(map, "idle", function() { 
		  if (map.getZoom() != 4) map.setZoom(4); 
		  google.maps.event.removeListener(listener); 
		});
		
	}, 'json');
});
