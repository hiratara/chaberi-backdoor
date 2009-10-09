( function ($) {

$( function () {
    $("#search-button").click( function () {
        $("#search-button").attr("disabled", "disabled");
        $("#wait-anime").show();

        var str   = $( "#search" ).val();
        var names = $(".member-names").get();

        Deferred.loop(
        { begin: 0, end: names.length, step: 20 }, function (n, o) {
            for (var i = n; i < n + o.step && i < names.length; i++){
                if( $( names[i] ).text().indexOf( str ) >= 0 ) 
                    $( names[i] ).parent().show();
                else
                    $( names[i] ).parent().hide();
            }
        }).error(function (e) {
            alert(e);
        }).next(function (){
            $("#wait-anime").hide();
            $("#search-button").removeAttr("disabled");
        });
    });
});

})(jQuery);