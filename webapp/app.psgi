use strict;
use warnings;
use AnyEvent;
use Chaberi::AnyEvent::Lobby;
use Plack::Request;
use Plack::Response;
use JSON;

my %connections;
my %now_using;

sub _connect($){
    my $host = shift;
    warn "connect $host" if $ENV{CHABERI_DEBUG};

    my ( $address, $port ) = split ':', $host;

    my $cv = AE::cv;
    my $lobby = Chaberi::AnyEvent::Lobby->new(
        address    => $address, port => $port,
        on_error   => sub { $cv->croak(@_) },
        on_connect => sub { $cv->send( $_[0] ) },
    );

    return $cv;
}

sub get_connection($){
    my $host = shift;
    my $future = AE::cv;

    my $do_rent = sub {
        $now_using{$host} = 1;
        $future->send( $connections{$host} );
    };

    if( $connections{$host} ){
        if( $now_using{$host} ){
            # TODO: wait for finishing to use
            $future->croak( 'now using. sorry.' );
            return;
        }
        $do_rent->();
    }else{
        (_connect $host)->cb(sub{
            # initialize the pool
            my $lobby = eval { $_[0]->recv };
            if($@){ 
                $future->croak( $_ );
                return;
            };

            $connections{$host} = $lobby;
            $lobby->on_disconnect( sub {
                warn "disconnect $host" if $ENV{CHABERI_DEBUG};
                delete $connections{$host};
            } );

            $do_rent->();
        });
    }

    return $future;
}

sub close_connection($){
    my $lobby = shift;
    delete $now_using{ $lobby->address . ':' . $lobby->port };
}

my $app = sub {
    my $req = Plack::Request->new( $_[0] );

    sub {
        my $respond = shift;

        my $host = $req->param('address') . ':' . $req->param('port');

        my $got_results = AE::cv;
        (get_connection $host)->cb(sub {
            my $lobby = eval { $_[0]->recv; };

            if($@){
                $respond->([500,[],[$@]]);
                return;
            }

            $lobby->get_members(
                ref_room_ids => [$req->param( 'room' )],
                cb           => sub { $got_results->send($lobby, $_[0]) },
            );
        });

        $got_results->cb(sub {
            my ($lobby, $results) = $_[0]->recv;

            my $res = Plack::Response->new( 200 );
            $res->content_type('text/plain');
            $res->body( JSON->new->utf8(1)->encode($results) );

            $respond->( $res->finalize );
            close_connection $lobby;
        });
    };
};
