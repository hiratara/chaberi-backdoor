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
            my $future = AE::cv;
            $future->croak( 'now using. sorry.' );
            return $future;
        }
        return $do_rent->();
    }else{
        # check the last failure to avoid sending request frequently.
        if( my $until = _wait_until $host ){
            my $future = AE::cv;
            $future->croak(
                'Under cool-down until ' . (scalar localtime $until)
            );
            return $future;
        }

        my $catch_cv = AE::cv;
        (_connect $host)->flat_map(sub {
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
        })->cb(sub {
            my @v = eval{ $_[0]->recv };
            $@ or return $catch_cv->(@v);

            _record_failure $host if $@ =~ /can't\s*connect/i;
            $catch_cv->croak( $@ );
        });

        return $catch_cv;
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

            my $cv = AE::cv;
            my $timeout = AE::timer 30, 0, sub {
                close_connection $lobby;
                $lobby->shutdown;

                $cv->croak("timeout\n");
            };

            $lobby->get_members(
                ref_room_ids => [$req->param( 'room' )],
                cb           => $cv,
            );
            $cv->map(sub {
                undef $timeout;
                close_connection $lobby;

                $_[0];
            });
        })->map(sub {
            my $results = shift;

            my $res = Plack::Response->new( 200 );
            $res->content_type('text/plain');
            $res->body( JSON->new->utf8(1)->encode($results) );

            $respond->( $res->finalize );
        })->cb(sub {
            eval { $_[0]->recv };
            $@ and $respond->([500,[],[$@]]);
        });
    };
};
