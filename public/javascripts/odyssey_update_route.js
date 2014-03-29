$(document).ready(function() {

    var deptimeChanged = false;
    var initDeptime = $('#deptime').val();
    
    $('#deptime').change(function() {

        deptimeChanged = ( $(this).val() !== initDeptime );
    });
    
    $('#update_route').click(function(evt) {

        var newEtd  = $('#deptime').val()       ,
            etd     = $('input#curretd').val()  ,
            srcId   = $('input#currsrc').val()  ,
            destId  = $('input#currdest').val() ;

        if (! deptimeChanged ) { // do Nothing
            evt.preventDefault();
            return;
        }

        // The departure time was updated. Get new
        // route options
        etd = etd.replace(/\d{2}:\d{2}:\d{2}\.\d{3}$/, newEtd);

        $.post('/update_route', {
            srcid  : srcId,
            destid : destId,
            etd    : etd
        }, function(data) {
            $('#optionholder').html(data);
        },
        'html'
        ).fail(function() {
            console.log('Route update failed');
        });

        evt.preventDefault();
        return;
    });

});
