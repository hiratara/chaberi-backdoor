BEGIN {
	package MyApp;
	use MooseX::POE;
	use POE::Component::Chaberi::Lobby::WWW;

	with 'POE::Component::Chaberi::Role::NextEvent';

	sub START {
		my $self = shift;
		for my $ch (0 .. 2) {
			for my $p (1 .. 5) {
				my $www = POE::Component::Chaberi::Lobby::WWW->new(
					cont => $self->next_event('recieve_parsed'),
					url  => "http://ch$ch.chaberi.com/$p",
				);
				$www->yield( 'exec' );
			}
		}
	}

	event 'recieve_parsed' => sub {
		my ($self, $parsed, $url) = @_[OBJECT, ARG0 .. $#_];
		my $bk = MyBackdoor->new(
			cont     => $self->next_event('recieve_rooms'),
			host     => $parsed->{host},
			port     => $parsed->{port},
			room_ids => [ map { $_->{id} } @{ $parsed->{rooms} } ],
		);
		$bk->yield( 'exec' );
		print "$parsed->{host},$parsed->{port},$url\n";
	};

	event 'recieve_rooms' => sub {
		my ($self, $ref_results) = @_[OBJECT, ARG0 .. $#_];
		for (@$ref_results){
			my $room_id  = $_->{room_id};
			my $room_ref = $_->{room_status};
			print "$room_id - " . @{ $room_ref->{members} } . "\n";
# 			use Data::Dumper;
# 			print "$room_id", Dumper($room_ref), "\n";
		}
	};

	no  MooseX::POE;


	package MyBackdoor;
	use MooseX::POE;
	use POE::Component::Chaberi::Lobby;

	with 'POE::Component::Chaberi::Role::NextEvent';

	has cont => (
		isa      => 'ArrayRef',
		is       => 'ro',
		required => 1,
	);

	has host => (
		isa      => 'Str',
		is       => 'ro',
		required => 1,
	);

	has port => (
		isa      => 'Int',
		is       => 'ro',
		required => 1,
	);

	has room_ids => (
		metaclass  => 'Collection::List',
		isa        => 'ArrayRef[Int]',
		is         => 'ro',
		required   => 1,
		provides => {
			elements => 'all_room_ids',
		},
	);

	has 'lobby' => (
		is => 'rw',
	);

	sub START {}

	event 'exec' => sub {
		my ($self) = @_[OBJECT, ARG0 .. $#_];
		my $lobby = POE::Component::Chaberi::Lobby->new(
			address => $self->host,
			port    => $self->port,
		);
		$lobby->register( $self->get_session_id );
		$lobby->yield( 'ready' );
	};

	event 'go' => sub {
		my ($self, $lobby) = @_[OBJECT, ARG0 .. $#_];
		$self->lobby( $lobby );
		$self->lobby->yield(
			'get_members' =>
			$self->next_event('recieve_members'), $self->room_ids,
		);
	};

	event 'recieve_members' => sub {
		my ($self, $ref_results) = @_[OBJECT, ARG0 .. $#_];
		$POE::Kernel::poe_kernel->post(
			@{ $self->cont }, $ref_results,
		);
		$self->lobby->yield( 'exit' );
	};

	event 'bye' => sub {
		warn 'bye';
	};

	no  MooseX::POE;

}

package main;
use POE;
use strict;
use warnings;
MyApp->new;

my $time = time;
POE::Kernel->run;
print time - $time, "\n";
