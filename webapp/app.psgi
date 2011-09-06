use strict;
use warnings;
use AnyEvent;
use Data::Monad::CondVar;
use Chaberi::AnyEvent::Lobby;
use Plack::Request;
use Plack::Response;
use JSON;

our $RETRY_PACE = 60 * 5;

my %connections;  # 'www.hoge.com:80' => CONNECTION
my %now_using;    # 'www.hoge.com:80' => 1
my %last_failure; # 'www.hoge.com'    => time()

sub _status{
    (
        "[connections]\n",
        ( map{ $_, ($now_using{$_} ? '(USING)' : () ), "\n" } 
            sort keys %connections ),
        "\n",
        "[failures]\n",
        ( map{ $_, ' until ', scalar localtime $last_failure{$_}, "\n" } 
            sort keys %last_failure ),
    );
}

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

    my $do_rent = sub {
        $now_using{$host} = 1;
        AnyEvent::CondVar->unit($connections{$host});
    };

    if( $connections{$host} ){
        if( $now_using{$host} ){
            # TODO: wait for finishing to use
            return AnyEvent::CondVar->fail( 'now using. sorry.' );
        }
        return $do_rent->();
    }else{
        # check the last failure to avoid sending request frequently.
        if( my $until = _wait_until $host ){
            return AnyEvent::CondVar->fail(
                'Under cool-down until ' . (scalar localtime $until)
            );
        }

        return (_connect $host)->flat_map(sub {
            # initialize the pool
            my $lobby = shift;

            $connections{$host} = $lobby;

            my $delete_connection = sub {
                warn "disconnect $host" if $ENV{CHABERI_DEBUG};
                delete $connections{$host};
            };
            $lobby->on_disconnect( $delete_connection );
            $lobby->on_error( $delete_connection );

            $do_rent->();
        })->catch(sub {
            my $exception = shift;

            _record_failure $host if $exception =~ /can't\s*connect/i;
            AnyEvent::CondVar->fail($exception);
        });
    }
}

sub close_connection($){
    my $lobby = shift;
    delete $now_using{ $lobby->address . ':' . $lobby->port };
}

my $app = sub {
    my $req = Plack::Request->new( $_[0] );

    return [200, ['Content-Type' => 'text/plain'], [_status]]
        if $req->path_info eq '/status';

    sub {
        my $respond = shift;

        my $host = $req->param('address') . ':' . $req->param('port');

        (get_connection $host)->flat_map(sub {
            my $lobby = shift;

            $lobby->get_members(
                ref_room_ids => [$req->param( 'room' )],
                cb           => (my $cv = AE::cv),
            );
            $cv->map(sub {
                close_connection $lobby;

                $_[0];
            })->timeout(30)->flat_map(sub {
                my $results = shift;
                return AnyEvent::CondVar->unit($results) if $results;

                # timeouted
                close_connection $lobby;
                $lobby->shutdown;

                AnyEvent::CondVar->fail("timeout\n");
            });
        })->map(sub {
            my $results = shift;

            my $res = Plack::Response->new( 200 );
            $res->content_type('text/plain');
            $res->body( JSON->new->utf8(1)->encode($results) );

            $respond->( $res->finalize );
        })->catch(sub {
            $respond->([500, [], [@_]]);
            AnyEvent::CondVar->unit(); # void
        });
    };
};
