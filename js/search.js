( function ($) {

$( function () {
    $("#search-button").click( function () {
        $("#search-button").attr("disabled", "disabled");
        $("#wait-anime").show();

        var str   = $( "#search" ).val();
        var match = $.map(
            $( "input[name=match]:checked" ).get(),
            function (elem, i) { return $( elem ).val(); }
        );
        var tr = $(".display-table tr").get();

        for(var i = 1; i < tr.length; i++){
          if($(tr[i]).text().indexOf(str)){
            for(var j = 0; j < match.length; j++){
              if($(match[j], tr[i]).text().indexOf( str ) >= 0 ){
                $(tr[i]).show();
                break
              }
              if(j === match.length-1)$(tr[i]).hide()
            }
          }else $(tr[i]).hide()
        }
        
        $("#search-button").removeAttr("disabled");
        $("#wait-anime").hide()
    });
});

})(jQuery);