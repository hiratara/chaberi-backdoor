package Chaberi::Backdoor::SearchPages;
use MooseX::POE;
use POE::Component::Chaberi::Lobby::WWW;
use Chaberi::Backdoor::LoadMembers;
use Chaberi::Backdoor::Collector;

with 'POE::Component::Chaberi::Role::NextEvent';

has cont => (
	isa      => 'ArrayRef',
	is       => 'ro',
	required => 1,
);

has collector => (
	isa => 'Maybe[Chaberi::Backdoor::Collector]',
	is  => 'rw',
);


sub START {
	my $self = shift;
	my @urls;
	for my $ch (0 .. 2) {
		for my $p (1 .. 5) {
			my $www = POE::Component::Chaberi::Lobby::WWW->new(
				cont => $self->next_event('recieve_parsed'),
				url  => "http://ch$ch.chaberi.com/$p",
			);
			$www->yield( 'exec' );
			push @urls, $www->url;
		}
	}

	$self->collector(
		Chaberi::Backdoor::Collector->new(
			cont => $self->cont,
			urls => \@urls,
		)
	);
}

event 'recieve_parsed' => sub {
	my ($self, $parsed, $url) = @_[OBJECT, ARG0 .. $#_];

	# add url as key
	$parsed->{url} = $url;

	my $bk = Chaberi::Backdoor::LoadMembers->new(
		cont     => $self->collector->next_event('finished'),
		page     => $parsed,
	);
	$bk->yield( 'exec' );
	print "$parsed->{host},$parsed->{port},$url\n";
};

no  MooseX::POE;
1;

=head1 NAME

Chaberi::Backdoor::SearchPages - search rooms in all pages.

=head1 DESCRIPTION

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
