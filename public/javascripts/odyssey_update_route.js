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

        // Show the loader, hide error...
        $('#ajax-loader').show();
        $('#ajax-error').hide();
        
        // The departure time was updated. Get new
        // route options
        etd = etd.replace(/\d{2}:\d{2}:\d{2}\.\d{3}$/, newEtd);

        $.post('/update_route', {
            srcid  : srcId,
            destid : destId,
            etd    : etd
        }, function(data) {
            $('#ajax-loader').hide();
            $('#optionholder').html(data);
        },
        'html'
        ).fail(function() {

            // Hide the loader, show error...
            $('#ajax-loader').hide();
            $('#ajax-error').show();
        });

        evt.preventDefault();
        return;
    });

});
