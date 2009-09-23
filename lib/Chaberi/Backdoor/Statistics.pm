package Chaberi::Backdoor::Statistics;
use strict;
use warnings;

# XXX This may be a blocking function which accesses to SQLite.
# $page, k1 => v1, k2 => v2, ..., $cb
sub update {
	my $page = shift;
	my $cb   = pop;
	my %params = @_;

	my $schema = delete $params{schema};
	my $now    = delete $params{now_epoch};

	Chaberi::Backdoor::Statistics::Task->new(
		page => $page,
		cb   => $cb,
		($schema ? (schema    => $schema) : ()),
		($now    ? (now_epoch => $now   ) : ()),
	)->update;
}

package Chaberi::Backdoor::Statistics::Task;
use Moose;
use Chaberi::Backdoor::Schema;

our $MARGINE = 20 * 60;  # 範囲が連続していると見なす幅


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


has schema => (
	isa     => 'Chaberi::Backdoor::Schema',
	is      => 'ro',
	default => sub { Chaberi::Backdoor::Schema->default_schema },
);


has now_epoch => (
	isa     => 'Int',
	is      => 'ro',
	default => sub { scalar time },
);


# subroutine =====================================
sub _calc_range{
	my $self = shift;
	my ($room, $nick) = @_;

	my $rs = $self->schema->resultset('EnterRange');

	my $cur_epoch = $rs->search(
		{
			room_id  => $room->id,
			nick_id  => $nick->id,
		}, 
	)->get_column('epoch2')->max;
	if ( $cur_epoch and $self->now_epoch - $cur_epoch < $MARGINE ) {
		# 前回の範囲を拡張する
		my $range = $rs->search(
			{
				room_id	 => $room->id,
				nick_id	 => $nick->id,
				epoch2	 => $cur_epoch,
			}, 
		)->first;
		$range->epoch2($self->now_epoch);
		$range->update;
		return $range;
	} else {
		# 新規範囲を作成
		return $rs->create(
			{
				room_id => $room->id,
				nick_id => $nick->id,
				epoch1 => $self->now_epoch,
				epoch2 => $self->now_epoch,
			}
		);
	}
}


# merge dbdata into page data (i.e. change page field destructively.)
sub _merge_statistics{
	my $self = shift;

	# load DB data
	for my $ref_room ( @{ $self->page->{rooms} }){
		my $room = $self->schema->resultset('Room')->find({
			unique_key => $ref_room->{url},
		});

		next unless $room;

		for my $ref_member ( @{ $ref_room->{members} } ){
			my $nick = $self->schema->resultset('Nick')->find_or_new(
				name => $ref_member->{name},
			)->insert();
			my $range = $self->_calc_range($room, $nick);

			$ref_member->{range} = [$range->epoch1, $range->epoch2];
		}
	}
}

sub update {
	my $self = shift;

	$self->_merge_statistics;

	# callback with page data
	$self->cb->( $self->page );
};

__PACKAGE__->meta->make_immutable;
no  Moose;
1;


=head1 NAME

Chaberi::Backdoor::Statistics - culculation with DB.

=head1 DESCRIPTION

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
