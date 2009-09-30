package Chaberi::Backdoor::LoadMembers;
use strict;
use warnings;

# $page, k1 => v1, k2 => v2, ..., $cb
sub load {
	my $page = shift;
	my $cb   = pop;
	my %params = @_;

	Chaberi::Backdoor::LoadMembers::Task->new(
		page => $page,
		cb   => $cb,
	)->load;
}


package Chaberi::Backdoor::LoadMembers::Task;
use Moose;
use Chaberi::Coro ();
use Chaberi::Backdoor::Statistics;

has cb => (
	isa      => 'CodeRef',
	is       => 'ro',
	required => 1,
);

has page => (
	isa      => 'HashRef',
	is       => 'ro',
	required => 1,
);

# Subroutines
sub host { shift->page->{_host} }
sub port { shift->page->{_port} }
sub room_ids { [ map { $_->{_id} } @{ shift->page->{rooms} } ] }


# merge result into page data (i.e. change page field destructively.)
sub _merge_result {
	my $self = shift;
	my ( $ref_results ) = @_;

	my %result = map { $_->{room_id} => $_->{room_status} } @$ref_results;

	for my $ref_room ( @{ $self->page->{rooms} } ){
		my $status = $result{ $ref_room->{_id} } or die;
		my @members = map { {
			name  => $_->name,
			range => undef, # we've not known it yet.
			# Do we need neither $_->status nor $_->is_owner ??
		} } $status->all_members;
		$ref_room->{ad}      = $status->advertising;
		$ref_room->{members} = \@members;
	}

	# cleaning.
	delete $_->{_id} for @{ $self->page->{rooms} };
	delete $self->page->{_host};
	delete $self->page->{_port};
}


sub load {
	my $self = shift;
	Coro::async {
		my $ref_results = Chaberi::Coro::get_members
			$self->host, $self->port, $self->room_ids;

		$self->_merge_result( $ref_results );

		Chaberi::Backdoor::Statistics::update
			$self->page,
			$self->cb
			;
	};
};


__PACKAGE__->meta->make_immutable;
no  Moose;

1;


=head1 NAME

Chaberi::Backdoor::LoadMembers - load members in a page.

=head1 DESCRIPTION

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
