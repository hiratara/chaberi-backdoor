use strict;
use warnings;
use Chaberi::AnyEvent::Lobby;
use Plack::Request;
use Plack::Response;
use JSON;

my $app = sub {
    my $req = Plack::Request->new( $_[0] );

    sub {
        my $respond = shift;

        my $lobby = Chaberi::AnyEvent::Lobby->new(
            address    => $req->param('address'),
            port       => $req->param('port'),
            on_error   => sub {
                $respond->( [500, [], ['ERROR:', @_]] );
            },
        );

        $lobby->get_members(
            ref_room_ids => [$req->param( 'room' )],
            cb           => sub {
                my $results = shift;

                my $res = Plack::Response->new( 200 );
                $res->content_type('text/plain');
                $res->body( JSON->new->utf8(1)->encode($results) );

                $lobby->shutdown;
                $respond->( $res->finalize );
            },
        );
    };
};
