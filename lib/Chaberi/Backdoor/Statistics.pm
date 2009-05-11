package Chaberi::Backdoor::Statistics;
use MooseX::POE;

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

sub START {}

event exec => sub {
	my ($self) = @_[OBJECT, ARG0 .. $#_];

	$POE::Kernel::poe_kernel->post(
		@{ $self->cont }, $self->page
	);
};

no  MooseX::POE;
1;
