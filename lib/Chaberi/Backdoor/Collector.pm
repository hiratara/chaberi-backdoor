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
	my ($self, $page) = @_[OBJECT, ARG0 .. $#_];

	for (@{ $page->{rooms} }) {
		my $room_id  = $_->{id};
		my $room_ref = $_->{status};
		print "$room_id - " . @{ $room_ref->{members} } . "\n";
	}

	$self->_done->{ $page->{url} } = 1;

	if( keys %{ $self->_done } >= @{ $self->urls } ){
		# exit
		$self->release_session;
	}

};

no  MooseX::POE;

__END__

=head1 NAME

Chaberi::Backdoor::Collector - collect all page's results

=head1 DESCRIPTION

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
