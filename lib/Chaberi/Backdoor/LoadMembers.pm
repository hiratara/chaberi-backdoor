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
sub host { shift->page->{_host} }
sub port { shift->page->{_port} }
sub room_ids { [ map { $_->{_id} } @{ shift->page->{rooms} } ] }


# merge result into page data (i.e. change page field destructively.)
sub _merge_result {
	my $self = shift;
	my ( $ref_results ) = @_;

	my %result = map { $_->{room_id} => $_->{room_status} } @$ref_results;

	for my $ref_room ( @{ $self->page->{rooms} } ){
		my $status = $result{ $ref_room->{_id} } or die;
		my @members = map { {
			name  => $_->name,
			range => undef, # we've not known it yet.
			# Do we need neither $_->status nor $_->is_owner ??
		} } $status->all_members;
		$ref_room->{ad}      = $status->advertising;
		$ref_room->{members} = \@members;
	}

	# cleaning.
	delete $_->{_id} for @{ $self->page->{rooms} };
	delete $self->page->{_host};
	delete $self->page->{_port};
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


=head1 NAME

Chaberi::Backdoor::LoadMembers - load members in a page.

=head1 DESCRIPTION

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
