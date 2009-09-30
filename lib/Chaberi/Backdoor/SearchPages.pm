package Chaberi::Backdoor::SearchPages;
use strict;
use warnings;
use Chaberi::Coro ();


# subroutines==================================================================
sub _create_page{
	my ( $url, $parsed ) = @_;

	my @rooms = map { {
		name => $_->{name}, 
		url  => $_->{link}, 
		ad      => undef, # we've not known yet.
		members => undef, # we've not known yet.
		_id  => $_->{id},
	} } @{ $parsed->{rooms} };

	return {
		name  => undef,  # we don't know.
		url   => $url,
		rooms => \@rooms,
		_host => $parsed->{host},
		_port => $parsed->{port},
	};
}


# my $page = Chaberi::Coro::parse_lobby $url;
sub search{
	my $url = shift;

	my $parsed = Chaberi::Coro::parse_lobby $url;

	# XXX I should implement codes to recovery.
	unless($parsed){
		# Failure. Return to Collector immediately.
		return{  # Return empty room data.
			name  => undef,
			url   => $url,
			rooms => [],
		};
	}

	# warn "$parsed->{host},$parsed->{port},$url\n";
	return _create_page $url, $parsed;
};

1;

=head1 NAME

Chaberi::Backdoor::SearchPages - search rooms in a page.

=head1 DESCRIPTION

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
