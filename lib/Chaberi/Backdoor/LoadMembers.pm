package Chaberi::Backdoor::LoadMembers;
use strict;
use warnings;
use Chaberi::Coro ();

# merge result into page data (i.e. change $page field destructively.)
sub _merge_result {
	my ( $page, $ref_results ) = @_;

	my %result = map { $_->{room_id} => $_->{room_status} } @$ref_results;

	for my $ref_room ( @{ $page->{rooms} } ){
		my $status = $result{ delete $ref_room->{_id} } or die;
		my @members = map { {
			name  => $_->name,
			range => undef, # we've not known it yet.
			# Do we need neither $_->status nor $_->is_owner ??
		} } $status->all_members;
		$ref_room->{ad}      = $status->advertising;
		$ref_room->{members} = \@members;
	}
}

# my $page = Chaberi::Backdoor::LoadMembers::load $page;
sub load {
	my $page = shift;

	my $host = delete $page->{_host};
	my $port = delete $page->{_port};
	my @room_ids = map { $_->{_id} } @{ $page->{rooms} };

	my $ref_results = Chaberi::Coro::get_members $host, $port, \@room_ids;

	_merge_result $page, $ref_results;

	return $page;
};

1;


=head1 NAME

Chaberi::Backdoor::LoadMembers - load members in a page.

=head1 DESCRIPTION

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
