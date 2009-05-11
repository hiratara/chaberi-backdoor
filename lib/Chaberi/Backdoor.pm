package Chaberi::Backdoor;
use MooseX::POE;
use Chaberi::Backdoor::SearchPages;

with 'POE::Component::Chaberi::Role::NextEvent';

sub START {
	my ($self) = @_[OBJECT, ARG0 .. $#_];
	Chaberi::Backdoor::SearchPages->new(
		cont => $self->next_event('finished'),
	);
}

event finished => sub {
	my ($self) = @_[OBJECT, ARG0 .. $#_];
	warn "finished;";
};

no  MooseX::POE;

