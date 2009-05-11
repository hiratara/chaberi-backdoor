package Chaberi::Backdoor::LoadMembers;
use MooseX::POE;
use POE::Component::Chaberi::Lobby;
use Chaberi::Backdoor::Statistics;

with 'POE::Component::Chaberi::Role::NextEvent';

has cont => (
	isa      => 'ArrayRef',
	is       => 'ro',
	required => 1,
);

has page => (
	isa      => 'HashRef',
	is       => 'ro',
	required => 1,
);

has 'lobby' => (
	is => 'rw',
);

# Subroutines
sub host { shift->page->{host} }
sub port { shift->page->{port} }
sub room_ids { [ map { $_->{id} } @{ shift->page->{rooms} } ] }


# merge result into page data (i.e. change page field destructively.)
sub _merge_result {
	my $self = shift;
	my ( $ref_results ) = @_;

	my %result = map { $_->{room_id} => $_->{room_status} } @$ref_results;

	for ( @{ $self->page->{rooms} } ){
		$_->{status} = $result{ $_->{id} } or die;
	}
}


# events from client ====================================
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


# events from POE::Component::Chaberi::Lobby ============
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

	$self->_merge_result( $ref_results );

	my $statistics = Chaberi::Backdoor::Statistics->new(
		cont => $self->cont,
		page => $self->page,
	);
	$statistics->yield('exec');

	# close lobby actor
	$self->lobby->yield( 'exit' );
};


event 'bye' => sub {
	warn 'bye';
};


no  MooseX::POE;
1;
