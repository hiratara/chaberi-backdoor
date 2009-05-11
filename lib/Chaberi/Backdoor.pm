package Chaberi::Backdoor;
use MooseX::POE;
use Chaberi::Backdoor::SearchPages;

with 'POE::Component::Chaberi::Role::NextEvent';

sub START {
	my ($self) = @_[OBJECT, ARG0 .. $#_];
	my $collector = Chaberi::Backdoor::Collector->new(
		cont => $self->next_event('finished'),
	);
	$collector->yield('exec');
}

event finished => sub {
	my ($self) = @_[OBJECT, ARG0 .. $#_];
	warn "finished;";
};

no  MooseX::POE;

__END__


=head1 NAME

Chaberi::Backdoor - backdoor of chaberi

=head1 DESCRIPTION

get chaberi data and make a html.

Backdoor -> Collector -> SearchPages -> LoadMembers -> Statistics +
                ^                                                 |
                |                                                 |
                +----------<------------<-------------<-----------+

SearchPages make page data(hashref), and Loadmembers and Statistics marge
information into it.

Collector catches the all page data, and write it down in html.

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
