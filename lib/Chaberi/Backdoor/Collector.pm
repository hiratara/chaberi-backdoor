package Chaberi::Backdoor::Collector;
use MooseX::POE;

with 'POE::Component::Chaberi::Role::NextEvent', 
     'POE::Component::Chaberi::Role::RetainSession';


has cont => (
	isa      => 'ArrayRef',
	is       => 'ro',
	required => 1,
);

has urls => (
	isa      => 'ArrayRef',
	is       => 'ro',
	required => 1,
);

has _done => (
	isa     => 'HashRef',
	is      => 'ro',
	default => sub { {} },
);


sub START{
	my ($self) = @_[OBJECT, ARG0 .. $#_];
	$self->retain_session;
}


event finished => sub {
	my ($self, $ref_results) = @_[OBJECT, ARG0 .. $#_];

	for (@{ $ref_results->{room_list} }) {
		my $room_id  = $_->{room_id};
		my $room_ref = $_->{room_status};
		print "$room_id - " . @{ $room_ref->{members} } . "\n";
	}

	$self->_done->{ $ref_results->{url} } = 1;

	if( keys %{ $self->_done } >= @{ $self->urls } ){
		# exit
		$self->release_session;
	}

};

no  MooseX::POE;
