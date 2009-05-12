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

has url => (
	isa      => 'Str',
	is       => 'ro',
	requires => 1,
);

# subroutines==================================================================
sub _create_page{
	my $self = shift;
	my ( $parsed ) = @_;

	my @rooms = map { {
		name => $_->{name}, 
		url  => $_->{link}, 
		ad      => undef, # we've not known yet.
		members => undef, # we've not known yet.
		_id  => $_->{id},
	} } @{ $parsed->{rooms} };

	return {
		name  => undef,  # we don't know.
		url   => $self->url,
		rooms => \@rooms,
		_host => $parsed->{host},
		_port => $parsed->{port},
	};
}

# event defs ==================================================================
sub START {
	my ($self) = @_[OBJECT, ARG0 .. $#_];
}

event exec => sub {
	my ($self) = @_[OBJECT, ARG0 .. $#_];
	my $www = POE::Component::Chaberi::Lobby::WWW->new(
		cont => $self->next_event('recieve_parsed'),
		url  => $self->url,
	);
	$www->yield( 'exec' );
};


event 'recieve_parsed' => sub {
	my ($self, $parsed, $url) = @_[OBJECT, ARG0 .. $#_];

	$self->url eq $url or die 'got unknown URL:' . $url;

	my $bk = Chaberi::Backdoor::LoadMembers->new(
		cont => $self->cont,
		page => $self->_create_page($parsed),
	);
	$bk->yield( 'exec' );

	warn "$parsed->{host},$parsed->{port},$url\n";
};

no  MooseX::POE;
1;

=head1 NAME

Chaberi::Backdoor::SearchPages - search rooms in a page.

=head1 DESCRIPTION

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
