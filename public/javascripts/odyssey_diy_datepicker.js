$(document).ready(function(){
	
	$('input#arrdate').datepicker({
		minDate: 0,
		dateFormat: 'D, M dd yy',
		onClose: function( selectedDate ) {
			$('#depdate').datepicker('option', 'minDate', selectedDate);
		}
	});

	$('input#depdate').datepicker({
		minDate: 0,
		dateFormat: 'D, M dd yy',
		onClose: function( selectedDate ) {
			$('#arrdate').datepicker('option', 'maxDate', selectedDate);
		}
	});
});
