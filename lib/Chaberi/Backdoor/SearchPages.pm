package Chaberi::Backdoor::SearchPages;
use MooseX::POE;
use Chaberi::Lobby::WWW;
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


sub search_pages{
	my $self = shift;

	Chaberi::Lobby::WWW::parse_lobby
		$self->url,
		sub { $self->recieve_parsed(@_) };
}


# cb for Chaberi::Lobby::WWW::parse_lobby
sub recieve_parsed {
	my $self = shift;
	my ($parsed, $url) = @_;

	$self->url eq $url or die 'got unknown URL:' . $url;

	# XXX I should implement codes to recovery.
	unless($parsed){
		# Failure. Return to Collector immediately.
		$POE::Kernel::poe_kernel->post(
			@{ $self->cont }, {  # Send empty room data.
				name  => undef,
				url   => $self->url,
				rooms => [],
			},
		);
		return;
	}

	# Pass results to next task.
	my $bk = Chaberi::Backdoor::LoadMembers->new(
		cont => $self->cont,
		page => $self->_create_page($parsed),
	);
	$bk->yield( 'exec' );

	# warn "$parsed->{host},$parsed->{port},$url\n";
};


# event defs ==================================================================
sub START {
	my ($self) = @_[OBJECT, ARG0 .. $#_];
}

event exec => sub {
	my ($self) = @_[OBJECT, ARG0 .. $#_];
	$self->search_pages;
};



no  MooseX::POE;
1;

=head1 NAME

Chaberi::Backdoor::SearchPages - search rooms in a page.

=head1 DESCRIPTION

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
