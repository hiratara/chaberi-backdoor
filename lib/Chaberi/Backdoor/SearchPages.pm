package Chaberi::Backdoor::SearchPages;
use strict;
use warnings;

# $url, k1 => v1, k2 => v2, ..., $cb
sub search {
	my $url = shift;
	my $cb  = pop;
	my %params = @_;

	Chaberi::Backdoor::SearchPages::Task->new(
		url => $url,
		cb  => $cb,
	)->search;
}


package Chaberi::Backdoor::SearchPages::Task;
use Moose;
use Chaberi::AnyEvent::Lobby::WWW;
use Chaberi::Backdoor::LoadMembers;
use Chaberi::Backdoor::Collector;

has cb => (
	isa      => 'CodeRef',
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


sub search{
	my $self = shift;

	Chaberi::AnyEvent::Lobby::WWW::parse_lobby
		$self->url,
		sub { $self->recieve_parsed(@_) };
}


# cb for Chaberi::AnyEvent::Lobby::WWW::parse_lobby
sub recieve_parsed {
	my $self = shift;
	my ($parsed, $url) = @_;

	$self->url eq $url or die 'got unknown URL:' . $url;

	# XXX I should implement codes to recovery.
	unless($parsed){
		# Failure. Return to Collector immediately.
		$self->cb->(
			{  # Callback with empty room data.
				name  => undef,
				url   => $self->url,
				rooms => [],
			},
		);
		return;
	}

	# Pass results to next task.
	Chaberi::Backdoor::LoadMembers::load
		$self->_create_page($parsed),
		$self->cb;

	# warn "$parsed->{host},$parsed->{port},$url\n";
};


__PACKAGE__->meta->make_immutable;
no  Moose;
1;

=head1 NAME

Chaberi::Backdoor::SearchPages - search rooms in a page.

=head1 DESCRIPTION

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
