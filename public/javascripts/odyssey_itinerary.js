$(document).ready(function(){

	var hldr = $('#daysleftstr');
	var tlen = parseInt( hldr.attr('tlen') );
	var dnum = parseInt( hldr.attr('dnum') );
	$('select#days').change(function(evt) {
		
		var newVal = parseInt( $(this).find(':selected').text() );
		var dbal = tlen - dnum - newVal + 1;
		var str = '';
		if (dbal > 0) {
			
			str = 'You will have ' + dbal + ' day(s) left until the end ' + 
				'of your tour if you choose this option.';
		}
		else if (dbal == 0) {

			str = 'You have no days left according to your original schedule ' + 
				'if you choose this option. Feel free to continue adding days ' +
				' and we will adjust the duration of your tour when we build ' 
				'your itinerary';
		}
		else {
			
			str = 'You will have added ' +  (0 - dbal) + ' day(s) to your original ' +
				'plan if you choose this option. Feel free to continue adding ' +
				'days and we will adjust the duration of your tour when we build ' + 
				'your itinerary';
		}
		
		hldr.html(str);
		return true;	
	});
});
