use strict;
use warnings;
use AnyEvent;
use Chaberi::AnyEvent::Lobby;
use Plack::Request;
use Plack::Response;
use JSON;

our $RETRY_PACE = 60 * 5;

my %connections;  # 'www.hoge.com:80' => CONNECTION
my %now_using;    # 'www.hoge.com:80' => 1
my %last_failure; # 'www.hoge.com'    => time()

sub _connect($){
    my $host = shift;
    warn "connect $host" if $ENV{CHABERI_DEBUG};

    my ( $address, $port ) = split ':', $host;

    my $cv = AE::cv;
    my $lobby = Chaberi::AnyEvent::Lobby->new(
        address    => $address, port => $port,
        on_error   => sub {
            # connecting failure
            my ($lobby, @msg) = @_; 
            $cv->croak(join ',', @msg);
        },
        on_connect => sub { $cv->send( $_[0] ) },
    );

    return $cv;
}

sub _record_failure($){
    my $host = shift;
    $host =~ s/:[^:]+$//;
    $last_failure{$host} = time;
}

sub _wait_until($){
    my $host = shift;
    (my $address = $host) =~ s/:[^:]+$//;

    return unless $last_failure{$address};

    if( time < $RETRY_PACE + $last_failure{$address} ){
        return $RETRY_PACE + $last_failure{$address};
    }else{
        delete $last_failure{$address};
        return;
    }
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
        # check the last failure to avoid sending request frequently.
        if( my $until = _wait_until $host ){
            $future->croak(
                'Under cool-down until ' . (scalar localtime $until)
            );
            return;
        }

        (_connect $host)->cb(sub{
            # initialize the pool
            my $lobby = eval { $_[0]->recv };
            if($@){ 
                _record_failure $host if $@ =~ /can't\s*connect/i;
                $future->croak( $@ );
                return;
            };

            $connections{$host} = $lobby;

            my $delete_connection = sub {
                warn "disconnect $host" if $ENV{CHABERI_DEBUG};
                delete $connections{$host};
            };
            $lobby->on_disconnect( $delete_connection );
            $lobby->on_error( $delete_connection );

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

            my $timeout = AE::timer 30, 0, sub {
                $lobby->shutdown;
                $respond->([500,[],["timeout\n"]]);
            };

            $lobby->get_members(
                ref_room_ids => [$req->param( 'room' )],
                cb           => sub {
                    undef $timeout;
                    $got_results->send($lobby,$_[0])
                },
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
