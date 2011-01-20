( function ($) {

$( function () {
    var isSearching = false;
    $("#search-button").click( function () {
        if (isSearching) return;

        isSearching = true;
        $("#wait-anime").show();

        var str   = $( "#search" ).val();
        var match = $.map(
            $( "input[name=match]:checked" ).get(),
            function (elem, i) { return $( elem ).val(); }
        );

        var tr = $(".display-table tr").get();
        Deferred.loop(
        { begin: 0, end: tr.length, step: 20 }, function (n, o) {
            for (var i = n; i < n + o.step && i < tr.length; i++){
                var matched = false;
                for(var j = 0; j < match.length; j++){
                    if( $(match[j], tr[i]).text().indexOf( str ) >= 0 )
                        matched = true;
                }
                if( matched )
                    $( tr[i] ).show();
                else
                    $( tr[i] ).hide();
            }
        }).error(function (e) {
            alert(e);
        }).next(function (){
            $("#wait-anime").hide();
            isSearching = false;
        });
    });

    $("#search").keydown(function (e) {
        if (e.keyCode == 13) $("#search-button").click();
    });
});

})(jQuery);